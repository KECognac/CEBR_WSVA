#' Adds well and aquifer metadata to nwis_groundwater dataframe based on USGS site_no 
#' @param nwis_groundwater a list of nwis groundwater sites returned and filtered from function 'listNWIS'
#'              

add_gw_meta <- function(nwis_groundwater) {

# Define function to get well metadata
get_well_meta <- function(gw_list) {
  
  # First, get well metadata using dataRetrieval function 'readNWISsite'
  nwis_site_dat <- dataRetrieval::readNWISsite(gw_list$site_no) %>% 
    dplyr::select(c("site_no",
                    "state_cd",
                    "huc_cd", 
                    "basin_cd", 
                    "topo_cd", 
                    "drain_area_va", 
                    "contrib_drain_area_va",
                    "nat_aqfr_cd", 
                    "aqfr_cd", 
                    "aqfr_type_cd", 
                    "well_depth_va"))
 
  nwis_groundwater_meta <- gw_list %>%
    dplyr::left_join(., nwis_site_dat, by = "site_no")  
  
  return(nwis_groundwater_meta)
  
}


if (nrow(nwis_groundwater) > 35000) {
  
  # Split the data frame into chunks of desired size (here, 35000 rows)

    df_list <- split(nwis_groundwater, 
                   ceiling(seq_len(nrow(nwis_groundwater)) / 35000))

  # Process each chunk and combine results
  nwis_groundwater_meta <- map_dfr(df_list, get_well_meta)
  
} else {
  nwis_groundwater_meta <- get_well_meta(gw_list = nwis_groundwater)
}
 
# Next get aquifer name from USGS database
  
# Read USGS aquifer code webpage using rvest
url <- "https://help.waterdata.usgs.gov/aqfr_cd"
webpage <- read_html(url)

# Extract and clean table containing aquifer codes
aquifer_table <- webpage %>%
  html_nodes("table") %>%  
  .[[1]] %>%                    # Select the first table
  html_table(fill = TRUE) %>%   # Extract table data
  data.table() %>%
  mutate("State Code" = as.character(`State Code`))

nwis_groundwater_meta <- nwis_groundwater_meta %>%
  dplyr::left_join(., aquifer_table, 
             by = c("aqfr_cd" = "Local Aquifer Code", 
                    "state_cd" = "State Code"))




# Next add aquifer type code description, from:
# https://help.waterdata.usgs.gov/code/aqfr_type_cd_query?fmt=rdb&inline=true

aquifer_type_codes <- data.frame(
  code = c('C', 'M', 'N', 'U', 'X'),
  desc = c('Confined single aquifer',
            'Confined multiple aquifers',
            'Unconfined multiple aquifer',
            'Unconfined single aquifer',
            'Mixed (confined and unconfined) multiple aquifers'
            )
)

nwis_groundwater_meta <- nwis_groundwater_meta %>%
  dplyr::left_join(aquifer_type_codes, by = c("aqfr_type_cd" = "code")) %>%
  # should never me empty. 
  filter(!is.na(huc_cd))



# Return updated dataframe with metadata columns
return(nwis_groundwater_meta)

}