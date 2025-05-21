#' Script developed by the LCSC-CSIC data team:
#'
#' - Magí Franquesa: Environmental Hydrology Climate and Human Activity Interactions,
#'   Geoenvironmental Processes, IPE-CSIC (magi.franquesa@ipe.csic.es).
#'
#' This program is free software: you can redistribute it and/or modify
#' it under the terms of the GNU General Public License as published by
#' the Free Software Foundation, either version 3 of the License, or
#' any later version.
#'
#' This program is distributed in the hope that it will be useful,
#' but WITHOUT ANY WARRANTY; without even the implied warranty of
#' MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
#' GNU General Public License for more details.
#'
#' You should have received a copy of the GNU General Public License
#' along with this program. If not, see <http://www.gnu.org/licenses/>
#' <http://www.gnu.org/licenses/gpl.txt/>.
#'
#' This script processes soil water capacity data to match the structure of ERA5-land data.
#'
#' Steps performed by the script:
#' 1. Read the URL from a text file to download the raw AWC data.
#' 2. Download the raw AWC data if it does not already exist.
#' 3. Process the raw AWC data to match the resolution and extent of ERA5-land data.
#' 4. Reclassify the processed AWC data based on predefined classes.
#' 5. Save the reclassified AWC data in NetCDF format.
#'
#' Libraries used:
#' - ncdf4: Provides functions to read and write NetCDF files.
#' - sf: Used for handling spatial data.
#' - raster: Used for raster data manipulation.
#' - dplyr: Provides data manipulation functions.
#' - terra: Used for spatial data analysis.
#'
#' Example usage:
#' - Place the URL of the soil data source in 'preprocessing/input_awc_source.txt'.
#' - Run the script to download, process, and reclassify the AWC data.
#'

###############################################################################
library(ncdf4)
library(sf)
library(raster)
library(dplyr)
library(terra)

# Read URL from text file
url_file <- "config/input_awc_source.txt"
awc_url <- readLines(url_file)

# Define paths
raw_awc_path <- "preprocessing/AWC_data/raw_awc_class.tif"
processed_awc_path <- "preprocessing/AWC_data/awc.nc"

# Step 1: Download the raw AWC file
if (!file.exists(raw_awc_path)) {
  message("Downloading AWC data...")
  download.file(awc_url, raw_awc_path, mode = "wb")
  message("Download complete: ", raw_awc_path)
} else {
  message("Raw AWC file already exists: ", raw_awc_path)
}

if (!file.exists(processed_awc_path)) {
  message("Processing AWC data...")
  awc_data <- raster::raster(raw_awc_path)
  points_data <- rasterToPoints(awc_data)
  points_df <- as.data.frame(points_data)
  names(points_df) <- c("x", "y", "awc")
  points_sf <- st_as_sf(points_df, coords = c("x", "y"), crs = st_crs(awc_data))

  #' Calculate the Most Frequent Value
  #'
  #' This function calculates the most frequent value(s) in a given vector.
  #'
  #' @param x A vector of values.
  #' @param k An integer specifying the number of most frequent values to return. Default is 1.
  #' @param ... Additional arguments (currently not used).
  #'
  #' @return A vector of the most frequent value(s) in the input vector.
  #'
  #' @examples
  #' mostfreqval(c(1, 2, 2, 3, 3, 3, 4), k = 1) # Returns 3
  #' mostfreqval(c(1, 2, 2, 3, 3, 3, 4), k = 2) # Returns c(3, 2)
  #'
  #' @export
  mostfreqval <- function(x, k = 1, ...) {
    if (!is.numeric(x) && !is.factor(x)) {
      x <- as.numeric(as.factor(x))
    }
    freq_table <- na.omit(x) %>% table() %>% sort(decreasing = TRUE)
    most_freq <- as.numeric(names(freq_table)[1])
    return(most_freq)
  }

  # The grid_era5_land_standar.nc has been created with the cdo tool installed in a docker with ubuntu:
  # https://stackoverflow.com/questions/57682977/converting-longitude-in-netcdf-from-0360-to-180180-using-nco
  grid_standar <- raster::raster("preprocessing/AWC_data/grid_era5_land_standar.nc")
  points_rasterized <- rasterize(points_sf, grid_standar, field = "awc", fun = mostfreqval)
  # The points_rasterized are now tranformed again to the 0-360 degrees format
  # We read the data.nc which is a ERA5 dataset so we can extrat the ERA5 extent
  # era5 data has been downloaded form the Copernicus Data Store:
  # https://cds.climate.copernicus.eu/cdsapp#!/dataset/reanalysis-era5-land?tab=form
  era_data <- raster("preprocessing/AWC_data/era5_land_data.nc")

  extent_east <- extent(-0.05, xmax(points_rasterized), ymin(points_rasterized), ymax(points_rasterized))
  extent_west <- extent(xmin(points_rasterized), -0.05, ymin(points_rasterized), ymax(points_rasterized))

  raster_east <- crop(points_rasterized, extent_east)
  raster_west <- crop(points_rasterized, extent_west)
  extent_west <- extent(raster_west)
  extent_west <- extent(179.95, 359.95, ymin(extent_west), ymax(extent_west))
  extent(raster_west) <- extent_west

  merged_raster <- merge(raster_east, raster_west)

  awc <- mask(merged_raster, era_data)

  awc_nodata <- is.na(values(awc))
  era5_data <- !is.na(values(era_data))
  values(awc)[awc_nodata & era5_data] <- 0

  rows <- nrow(awc)
  row_indices <- rowFromCell(awc, 1:ncell(awc))
  row_nodata <- row_indices > 1500
  values(awc)[row_nodata] <- NA

  # Reclassify the data directly
  reclass_matrix <- matrix(c(6.99, 7.01, 0,
                             5.99, 6.01, 15,
                             4.99, 5.01, 50,
                             3.99, 4.01, 75,
                             2.99, 3.01, 100,
                             1.99, 2.01, 125,
                             0.99, 1.01, 150), ncol = 3, byrow = TRUE)

  reclassed_data <- reclassify(awc, reclass_matrix)

  # Save the reclassified data directly to NetCDF
  lons <- ncvar_get(nc_open("preprocessing/AWC_data/era5_land_data.nc"), "longitude")
  lats <- ncvar_get(nc_open("preprocessing/AWC_data/era5_land_data.nc"), "latitude")
  awc_var <- values(reclassed_data)

  dimLon <- ncdf4::ncdim_def(name = "lon",
                             units = "degrees_east",
                             vals = lons,
                             longname = "longitude")

  dimLat <- ncdf4::ncdim_def(name = "lat",
                             units = "degrees_north",
                             vals = lats,
                             longname = "latitude")

  varCRS <- ncdf4::ncvar_def(name = "crs",
                             units = "",
                             dim = list(),
                             longname = "CRS definition",
                             prec = "integer")

  var <- ncdf4::ncvar_def(name = "AWC",
                          units = "mm/m",
                          dim = list(dimLon, dimLat),
                          missval = NaN,
                          longname = "available_water_capacity",
                          prec = "float",
                          compression = 9)

  nc <- ncdf4::nc_create(processed_awc_path, vars = list(var, varCRS), force_v4 = TRUE)

  ncdf4::ncatt_put(nc, "AWC", "grid_mapping", "crs")
  ncdf4::ncatt_put(nc, "crs", "grid_mapping_name", "latitude_longitude")
  ncdf4::ncatt_put(nc, "crs", "longitude_of_prime_meridian", 0.0)
  ncdf4::ncatt_put(nc, "crs", "semi_major_axis", 6378137.0)
  ncdf4::ncatt_put(nc, "crs", "inverse_flattening", 298.257223563)
  ncdf4::ncatt_put(nc, "crs", "crs_wkt", 'GEOGCRS["WGS 84", ENSEMBLE["World Geodetic System 1984 ensemble",
                   MEMBER["World Geodetic System 1984 (Transit)"],
                   MEMBER["World Geodetic System 1984 (G730)"],
                   MEMBER["World Geodetic System 1984 (G873)"],
                   MEMBER["World Geodetic System 1984 (G1150)"],
                   MEMBER["World Geodetic System 1984 (G1674)"],
                   MEMBER["World Geodetic System 1984 (G1762)"],
                   MEMBER["World Geodetic System 1984 (G2139)"],
                   ELLIPSOID["WGS 84",6378137,298.257223563,
                             LENGTHUNIT["metre",1]],
                   ENSEMBLEACCURACY[2.0]],
          PRIMEM["Greenwich",0,
                 ANGLEUNIT["degree",0.0174532925199433]],
          CS[ellipsoidal,2],
          AXIS["geodetic latitude (Lat)",north,
               ORDER[1],
               ANGLEUNIT["degree",0.0174532925199433]],
          AXIS["geodetic longitude (Lon)",east,
               ORDER[2],
               ANGLEUNIT["degree",0.0174532925199433]],
          USAGE[
            SCOPE["Horizontal component of 3D system."],
            AREA["World."],
            BBOX[-90,-180,90,180]],
          ID["EPSG",4326]]')

  ncdf4::ncatt_put(nc, "lon", "long_name", "longitude")
  ncdf4::ncatt_put(nc, "lon", "standard_name", "longitude")
  ncdf4::ncatt_put(nc, "lon", "axis", "X")
  ncdf4::ncatt_put(nc, "lon", "comment", "Longitude geographical coordinates, WGS84 projection")
  ncdf4::ncatt_put(nc, "lon", "reference_datum", "geographical coordinates, WGS84 projection")

  ncdf4::ncatt_put(nc, "lat", "long_name", "latitude")
  ncdf4::ncatt_put(nc, "lat", "standard_name", "latitude")
  ncdf4::ncatt_put(nc, "lat", "axis", "Y")
  ncdf4::ncatt_put(nc, "lat", "comment", "Latitude geographical coordinates, WGS84 projection")
  ncdf4::ncatt_put(nc, "lat", "reference_datum", "geographical coordinates, WGS84 projection")

  ncdf4::ncvar_put(nc, "AWC", awc_var)
  nc_close(nc)

  message("Processed and reclassified AWC data saved to: ", processed_awc_path)
} else {
  message("Processed AWC file already exists: ", processed_awc_path)
}
