# CEBR_WSVA

Cedar Breaks Water Supply Vulnerability Assessment (WSVA) for Blowhard Spring

## Report status

**Draft, in review.** *Water for People: Water Supply Vulnerability Assessment for Water Supplies at Cedar Breaks National Monument* (draft, 2026). A link to the published report will be added here once it is available on the NPS DataStore.

Prepared by Kristen Cognac, Kathryn Willi, Cibi Vishnu Chinnasamy (Radical Open Science Syndicate, Colorado State University), Caitlin Mothes (Geospatial Centroid, Colorado State University), Tyler Gilkerson (NPS Water Resources Division), and David Lawrence (NPS Climate Change Response Program).

## About the assessment

Cedar Breaks National Monument (CEBR) relies entirely on Blowhard Spring, a small, snowmelt-driven perennial spring on the monument's southwest rim. This assessment evaluates the vulnerability of the spring and the monument's water system to projected mid-century climate change and growing visitor demand. Vulnerability is assessed as a function of exposure and sensitivity across six categories: water balance, drought, water demand, wildfire, water quality, and water rights.

The analysis runs the NPS Water Balance Model for the Blowhard Spring recharge area with historical (GridMET) and 40 projected (MACA, CMIP5) climate datasets, routes modeled runoff to spring flow with a calibrated routing function, and compares projected supply with visitation-based demand and storage. Results focus on two contrasting climate futures that bracket projected runoff change: a "Drier" future (MIROC-ESM-CHEM, RCP 8.5) and a "Wetter" future (CanESM2, RCP 8.5).

## Repository contents

- `Reports/CEBR_Deep_Dive.Rmd`: prepares the data inputs, analyses, tables, and figures for the report
- `setup.R`: installs/loads required packages and sources every function in `src/`
- `src/`: the functions the report uses, including the NPS Water Balance Model (`src/NPS_WBM/`), the runoff routing function (`src/runoff_routing/`), and state water-rights retrieval functions

## Running the report

The report reads and writes data under a `data/` folder at the repository root, which is not tracked in git. On the project team's machines, `data/` is a symbolic link to the shared project data folder. The Rmd expects the following:

- `data/park/CEBR/`: park-specific inputs (springs, spring flow records, climate data, geology, sinkholes)
- `data/all/`: national datasets (water balance model rasters, NLCD, wildfire hazard potential, fire perimeters, pyromes, Gao et al. 2021 fire projections)
- `data/park/ZION/`: shared site-visit, isotope, and Spring Stewardship Institute data used for both parks

Running the Rmd also creates or updates:

- `data/park/CEBR/report_data/`: copies of downloaded inputs (NOAA, SNOTEL, NWIS, NHD/WBD, elevation, visitation, water rights, and others). These are downloaded once and reused on later runs; delete a file, or set `refresh = TRUE` in `cache_download()`, to pull a fresh copy.
- `data/park/CEBR/tables/`: CSV files of the report tables and the statistics cited in the text
- `data/park/CEBR/Figs/`: report figures

The final `save` chunk overwrites `data/park/CEBR/CEBR_report_data.RData` with the current workspace; skip that chunk if you don't intend to replace the saved workspace.

## Key analysis settings

These are set once in the Rmd and used throughout:

- **Analysis periods:** 1980–2012 historical baseline and 2035–2064 future period (`hist_yrs`, `fut_yrs`). The water balance model is run from 1979, which serves as a spin-up year.
- **Spring flow routing:** scale factor `f = 0.010` and slowflow fraction `vs = 0.5`, with quickflow and slowflow time constants of 24 and 68 days. These were calibrated against Blowhard Spring flow measurements (1979–1984, excluding duplicate 1983 records; NSE = 0.76). Low/high bounds use `f = 0.005` / `0.015` with `vs = 0.4` / `0.7`.
- **Drought:** 6-month SPEI on a monthly time step, normalized to 1980–2023
- **Storage:** 150,000-gallon storage tank, simulated continuously at a monthly time step

## History

This code was moved from [nps_water_vulnerability](https://github.com/Water-Vulnerability-Analytics/nps_water_vulnerability) with its commit history preserved.
