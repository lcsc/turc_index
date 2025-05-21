library(ncdf4)
library(abind)

source("../functions.R")

# Parse command-line arguments for start and end years
args <- commandArgs(trailingOnly = TRUE)
if (length(args) != 2) {
  stop("Usage: Rscript main_generate.R <start_year> <end_year>")
}
start_year <- as.numeric(args[1])
end_year <- as.numeric(args[2])

# Paths to input NetCDF files
input_files <- list(
  tmean = paste0("../../preprocessing/ERA5_land_data/update_data/tmean_", start_year, "_", end_year, ".nc"),
  tmin = paste0("../../preprocessing/ERA5_land_data/update_data/tmin_", start_year, "_", end_year, ".nc"),
  rh = paste0("../../preprocessing/ERA5_land_data/update_data/rh_", start_year, "_", end_year, ".nc"),
  rs = paste0("../../preprocessing/ERA5_land_data/update_data/solar_radiation_", start_year, "_", end_year, ".nc"),
  prec = paste0("../../preprocessing/ERA5_land_data/update_data/precipitation_", start_year, "_", end_year, ".nc"),
  awc = "../../preprocessing/AWC_data/awc.nc" # Available water capacity
)

# Open NetCDF files
nc_data <- lapply(input_files, nc_open)

# Get dimensions
lats <- ncvar_get(nc_data$tmin, "lat")
lons <- ncvar_get(nc_data$tmin, "lon")
time_steps <- length(ncvar_get(nc_data$tmin, "time"))
time_units <- ncatt_get(nc_data$tmin, "time", "units")$value
time_reference <- sub(".*since ", "", time_units)
time_vals <- ncvar_get(nc_data$tmin, "time") / 24 # Convert to days
time_dates <- as.Date(time_vals, origin = time_reference) # Convert to dates
time_numeric <- as.numeric(time_dates) # Convert to numeric with origin 1970-01-01

# Define the block to start from
# Change this number if execution was interrupted (e.g., 701)
start_block <- 1    # usually 1 to start from the beginning

# Define block size for latitudes
block_size <- 50  # Adjust this value based on memory capacity
lat_blocks <- seq(1, length(lats), by = block_size)

# Initialize output NetCDF file
output_file <- paste0("../../outputs/CA_", start_year, "_", end_year, ".nc")

#if (file.exists(output_file)) {
#  cat("Output file already exists. Do you want to overwrite it? (yes/no): ")
#  response <- tolower(readLines(con = stdin(), n = 1))
#  if (response != "yes") {
#    stop("Execution stopped by the user.")
#  }
#}
if (start_block == 1) {
    create_ncdf(output_file, var_name = "CA", lons = lons, lats = lats, vals = time_numeric)
}


start_time <- Sys.time()
cat("Script started at:", start_time, "\n")

# Loop over latitude blocks
for (block_start in lat_blocks) {
  cat("Processing block starting at latitude index:", block_start, "\n")
  block_end <- min(block_start + block_size - 1, length(lats))
  lat_indices <- block_start:block_end

  # Read subsets for this block
  variables <- list(
    tmean = ncvar_get(nc_data$tmean, "tmean", start = c(1, lat_indices[1], 1), count = c(length(lons), length(lat_indices), -1)),
    tmin = ncvar_get(nc_data$tmin, "tmin", start = c(1, lat_indices[1], 1), count = c(length(lons), length(lat_indices), -1)),
    rh = ncvar_get(nc_data$rh, "rh", start = c(1, lat_indices[1], 1), count = c(length(lons), length(lat_indices), -1)),
    rs = ncvar_get(nc_data$rs, "ssrd", start = c(1, lat_indices[1], 1), count = c(length(lons), length(lat_indices), -1)) / 1e6,
    prec = ncvar_get(nc_data$prec, "tp", start = c(1, lat_indices[1], 1), count = c(length(lons), length(lat_indices), -1)) * 1000 * 30,
    awc = ncvar_get(nc_data$awc, "AWC", start = c(1, lat_indices[1]), count = c(length(lons), length(lat_indices)))
  )

  # Initialize results for this block
  results_block <- array(NA, dim = c(length(lons), length(lat_indices), time_steps))

  # Process each grid cell in the block
  for (i in seq_along(lons)) {
    for (j in seq_along(lat_indices)) {
      try_result <- try(
        turc_index(
          Tmean = variables$tmean[i, j, ],
          Tmin = variables$tmin[i, j, ],
          RH = variables$rh[i, j, ],
          Rs = variables$rs[i, j, ],
          Prec = variables$prec[i, j, ],
          years.data = time_steps / 12,
          lat = lats[lat_indices[j]],
          WFC = variables$awc[i, j]
        ), silent = TRUE
      )

      if (!inherits(try_result, "try-error")) {
        results_block[i, j, ] <- try_result
      }
    }
  }

  # Write the results of this block to the NetCDF file
  cat("Writing results for latitude indices:", lat_indices, "to NetCDF file\n")
  write_ncdf_block(output_file, results_block, lons, lats[lat_indices], time_steps, lat_indices)
  
  # ✔️ Log progress to file
  cat(paste0("✅ Finished latitude block ", block_start, " to ", block_end, " at ", Sys.time(), "\n"),
      file = "log_blocks.txt", append = TRUE)

  # ♻️ Free memory
  rm(variables, results_block, try_result)
  gc()
}

end_time <- Sys.time()
cat("Script finished at:", end_time, "\n")
cat("Total execution time:", end_time - start_time, "\n")

# Close NetCDF files
lapply(nc_data, nc_close)
gc()
cat("NetCDF files closed.\n")
