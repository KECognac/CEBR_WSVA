#' Delineate watershed boundaries for an area of interest (AOI)
#'
#' @description
#' Given an AOI polygon, this function queries the NHDPlus network to construct
#' a watershed boundary. It identifies flowlines crossing the AOI boundary,
#' retrieves upstream contributing basins, and removes problematic or escaping
#' catchments. The result is a clean watershed polygon that encompasses the AOI
#' and removes artifacts such as stray catchments or holes.
#'
#' @details
#' **Workflow summary:**
#' - Loads the full NHD flow network (tabular form) for efficient lookup.
#' - Downloads NHDPlus flowlines within the AOI.
#' - Identifies flowlines that cross or leave the AOI boundary.
#' - Builds candidate watersheds by retrieving NLDI basins for those flowlines.
#' - Flags problematic "escaper" or "mystery" catchments that do not
#'   connect cleanly to the AOI and removes them.
#' - Merges the cleaned watershed with the AOI polygon, ensures validity,
#'   removes holes, and selects the largest polygon by area as the final output.
#'
#' This function temporarily disables `s2` geometry processing for stability
#' and re-enables it at the end.
#'
#' @param aoi An `sf` polygon object representing the area of interest.
#'
#' @return An `sf` polygon object representing the cleaned watershed boundary
#'         encompassing the AOI.
getAOIWatersheds <- function(aoi){
  
  # Ensure geometry column is named "geometry"
  geom_col <- attr(aoi, "sf_column")
  if (!"geometry" %in% names(aoi)) {
    names(aoi)[names(aoi) == geom_col] <- "geometry"
    attr(aoi, "sf_column") <- "geometry"
    aoi <- aoi %>% st_as_sf()
  }
  
  sf::sf_use_s2(FALSE)
  # read in the complete NHD (in tabular form) to make for much more efficient nhd crawling. 
  # This data in tabular form doesn't exist anywhere online that I know of... -_-
  nhd <- data.table::fread('data/all/nhd_flow_network.csv') 
  
  # download flowlines for entire aoi
  nhd_flowlines <- nhdplusTools::get_nhdplus(AOI = aoi, 
                                             realization='flowline',
                                             t_srs = sf::st_crs(aoi))
  
  # add `tocomid` field to ID flowlines that cross over the aoi
  # this step massively speeds up run time by reducing the number
  # of watersheds that need to be created
  aoi_flowlines <- nhd_flowlines  %>%
    dplyr::distinct(comid, .keep_all=TRUE) %>%
    nhdplusTools::get_tocomid(., add=TRUE)
  
  # minimize number of origin points by selecting only those that cross AOI boundary
  outsiders <- aoi_flowlines %>%
    dplyr::filter(tocomid==0) %>%
    tibble::rowid_to_column(., "index")
  
  watersheds <- vector("list", length = nrow(outsiders))
  
  for(i in 1:nrow(outsiders)){
    
   watersheds[[i]] <- nhdplusTools::get_nldi_basin(list("comid", as.character(outsiders$comid[i])))
    
  }
  
  main_watershed <- dplyr::bind_rows(watersheds) %>%
    sf::st_make_valid() %>%
    dplyr::summarize() %>%
    nngeo::st_remove_holes()
  
  
  watersheds <- vector("list", length = nrow(outsiders))
  
  for(i in 1:nrow(outsiders)){
    
    watersheds[[i]] <- nhdplusTools::get_UT(network = nhd,
                                            comid = outsiders$comid[i]) %>%
      as_tibble() %>%
      mutate(catchment = outsiders$comid[i])
    
  }
  
  flowline_list <- dplyr::bind_rows(watersheds) %>%
    group_by(value) %>%
    summarize(count = n()) %>%
    filter(count > 1)

  if(st_crs(main_watershed) != st_crs(aoi)){
    main_watershed <- main_watershed %>%
      st_transform(., st_crs(aoi))
  }
  
  sub_ws <- vector("list", length(nrow(outsiders)))
  
  for(i in 1:nrow(outsiders)){
    sub_ws[[i]] <- nhdplusTools::get_DM(network = nhd,
                                        comid = outsiders$comid[i],
                                        distance = 35) %>%
      as_tibble() %>%
      mutate(catchment = outsiders$comid[i])
  }
  
  
  # if no downstream segments in the AOI = escaping flowline OR something weird
  funky_ws <- bind_rows(sub_ws) %>%
    filter(value %in% nhd_flowlines$comid) %>%
    group_by(catchment) %>%
    summarize(count = n()) %>%
    filter(count == 1)
  
  # If many downstream segments in the AOI... likely escaper that returns to aoi 
  # only need  what is within the AOI.
  escapers <-  bind_rows(sub_ws) %>%
    filter(!value %in% nhd_flowlines$comid) %>%
    group_by(catchment) %>%
    mutate(count = n()) %>%
    filter(count > 1) %>%
    filter(!catchment %in% flowline_list$value)
  
  funk_finder <- vector("list", length = nrow(funky_ws))
  
  # of those mystery locs...
  for(i in 1:nrow(funky_ws)){
    funk_finder[[i]] <- nhdplusTools::get_UT(network = nhd,
                                             comid = funky_ws$catchment[i],
                                             distance = 35) %>%
      as_tibble() %>%
      #filter(value %in% nhd_flowlines$comid) %>%
      mutate(catchment = funky_ws$catchment[i])
  }
  
  # Those that have no upstream or downstream segments inside the aoi
  # are strange. Remove their extents outside of the AOI.
  mystery_flowlines <- bind_rows(funk_finder) %>%
    filter(value %in% nhd_flowlines$comid) %>%
    group_by(catchment) %>%
    mutate(count = n()) %>%
    filter(count == 1) 
  
  mystery_cats <- get_nhdplus(comid = mystery_flowlines$catchment, realization = "catchment",
                              t_srs = sf::st_crs(aoi))
  
  escaper_cats <- get_nhdplus(comid = escapers$catchment, realization = "catchment",
                              t_srs = sf::st_crs(aoi))
  
  bads <- mystery_cats %>% bind_rows(escaper_cats)
  
  bad_cats_removed <- main_watershed %>%
    st_difference(., st_union(bads)) 
  
  final_ws <- bind_rows(st_make_valid(aoi), bad_cats_removed) %>%
    summarize() %>%
    nngeo::st_remove_holes() %>%
    st_make_valid() %>%                           # guard against invalid rings
    st_cast("POLYGON") %>%                        # split MULTIPOLYGON into rows
    mutate(.area = as.numeric(st_area(geometry))) %>% 
    slice_max(.area, n = 1, with_ties = FALSE) %>% 
    select(-.area)
  
  sf::sf_use_s2(TRUE)
  return(final_ws)
  
}
