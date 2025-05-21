#'  Script developed by the LCSC-CSIC data team:
#'
#' - Magí Franquesa: Environmental Hydrology, Climate and Human Activity Interactions,
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

######################## FUNCTIONS ############################################

# --- Main Function ---
#' Calculate the Turc Index
#' @param Tmean Mean temperature (vector)
#' @param Tmin Minimum temperature (vector)
#' @param RH Relative humidity (%) (vector)
#' @param Prec Precipitation (mm) (vector)
#' @param Rs Solar radiation (MJ/m^2/day) (vector)
#' @param years.data Number of years in the dataset
#' @param lat Latitude of the location (degrees)
#' @param WFC Water Field Capacity (initial water balance value)
#' @return A vector containing the Combined Turc Index result (CA)

turc_index <- function(Tmean, Tmin, RH, Prec, Rs, years.data, lat, WFC) {
  # Function: turc_index
  # Purpose: Calculates a hydrometeorological index (Turc Index) based on temperature,
  #          relative humidity, precipitation, solar radiation, latitude, and water field capacity (WFC).
  #
  # Inputs:
  #   Tmax       - Maximum temperature (vector)
  #   Tmin       - Minimum temperature (vector)
  #   RH         - Relative humidity (%) (vector)
  #   Prec       - Precipitation (mm) (vector)
  #   Rs         - Solar radiation (MJ/m^2/day) (vector)
  #   years.data - Number of years in the dataset
  #   lat        - Latitude of the location (degrees)
  #   WFC        - Water Field Capacity (initial water balance value)
  #
  # Output:
  #   A vector containing the Combined Turc Index result (CA)

  # --- 1. Julian days setup ---
  YearlyMidpoints <- rep(c(15, 46, 74, 104, 135, 165, 196, 227, 257, 288, 318, 349), years.data)  # Midpoint days for each month
  
  # --- 2. Solar factor (Fh) ---
  # Solar declination angle (radians)
  delta <- 0.409 * sin(0.0172 * YearlyMidpoints - 1.39)
  # Latitude in radians
  latr <- lat / 57.2957795

  # Sunset hour angle (omegas)
  omegas <- acos(pmin(pmax(-tan(latr) * tan(delta), -1), 1))  # Ensure omegas is in [-1, 1]

  # Day length (N)
  DayLengthInHours <- 7.64 * omegas  # Approximate day length in hours

  # Solar factors (Fh1, Fh2)
  Fh1 <- DayLengthInHours - 5 - ((lat / 40)^2)  # Adjustment for latitude and day length
  Fh2 <- 0.03 * ((Rs * 23.884) - 100)  # Solar radiation contribution
  Fh1.2 <- pmin(Fh1, Fh2)  # Minimum solar factor between Fh1 and Fh2
  Fh <- pmax(Fh1.2, 0)  # Set negative values to zero

  # --- 3. Thermal factor (Ft) ---
  Ft.1 <- (Tmean * (60 - Tmean) / 1000) * ((Tmin - 1) / 4)  # Adjusted factor when Tmin is between 1 and 5
  Ft.2 <- Tmean * (60 - Tmean) / 1000  # Standard thermal factor
  Ft <- ifelse(Tmin <= 1, 0, ifelse(Tmin < 5, Ft.1, Ft.2))  # Conditions for Tmin

  # --- 4. Reference evapotranspiration (ETo) ---
  ETo.1 <- 0.4 * (Tmean / (Tmean + 15)) * (23.884 * Rs + 50)  # ETo for RH > 50%
  ETo.2 <- ETo.1 * (1 + (50 - RH) / 70)  # Adjusted ETo for RH <= 50%
  ETo <- ifelse(RH > 50, ETo.1, ETo.2)  # Conditional ETo
  ETo <- pmax(ETo, 0)  # Prevent negative ETo values

  # --- 5. Water balance calculation ---
  # Initialize variables for water balance
  ET <- R <- DIF <- rep(0, length(Tmean))  # ET: actual evapotranspiration; R: water reserve; DIF: water balance difference
  R[1] <- WFC  # Initial water reserve

  for (i in 2:length(Tmean)) {
    # Update water reserve (R): it cannot exceed 100 or go below 0
    R[i] <- pmin(pmax(R[i - 1] + Prec[i - 1] - ET[i - 1], 0), 100)

    # Water balance difference
    DIF[i] <- R[i] + Prec[i] - ETo[i]

    # Actual evapotranspiration
    ET[i] <- ifelse(DIF[i] > 0, ETo[i], R[i] + Prec[i])
  }

  # --- 6. Dryness factor (Fs) ---
  X <- pmin(ETo, ETo * 0.3 + 50)  # Adjusted dryness threshold
  EtDeficit <- ETo - ET  # Evapotranspiration deficit
  # Dryness factor (Fs), constrained to non-negative values
  Fs <- ifelse(X == 0 & EtDeficit == 0, 0, pmax((X - EtDeficit) / X, 0))

  # --- 7. Final Turc Index calculation (CA) ---
  CA <- Fh * Ft * Fs  # Combined index: product of solar, thermal, and dryness factors

  return(CA)
}

# --- Helper Functions ---

# Function to create an empty NetCDF file
#' Create an empty NetCDF file
#'
#' @param file_name The name of the NetCDF file to create.
#' @param var_name The name of the variable to store in the NetCDF file.
#' @param lons A numeric vector of longitude values.
#' @param lats A numeric vector of latitude values.
#' @param time_steps The number of time steps.
#' @return None. The function creates an empty NetCDF file.
#' @export

create_ncdf <- function(file_name, var_name, lons, lats, vals) {
  lons_nc <- ncdf4::ncdim_def("lon", "degrees_east", lons)
  lats_nc <- ncdf4::ncdim_def("lat", "degrees_north", lats)
  times_nc <- ncdf4::ncdim_def("time", "days since 1970-01-01 00:00:00", vals, unlim = TRUE)

  var_def <- ncdf4::ncvar_def(var_name, "1", list(lons_nc, lats_nc, times_nc), missval = NA, prec = "double", compression = 9)
  nc_file <- ncdf4::nc_create(file_name, var_def)
  ncdf4::nc_close(nc_file)
}

# Function to write a block of data to an existing NetCDF file
#' Write a block of data to an existing NetCDF file
#'
#' @param file_name The name of the NetCDF file.
#' @param data_block A 3D array containing the data block to write.
#' @param lons A numeric vector of longitude values for the block.
#' @param lats A numeric vector of latitude values for the block.
#' @param time_steps The total number of time steps.
#' @param lat_indices The indices of the latitude block being written.
#' @return None. The function writes the block to the NetCDF file.
#' @export
write_ncdf_block <- function(file_name, data_block, lons, lats, time_steps, lat_indices) {
  nc_file <- ncdf4::nc_open(file_name, write = TRUE)

  for (t in seq_len(dim(data_block)[3])) {
    ncdf4::ncvar_put(
      nc_file, varid = nc_file$var[[1]]$name, vals = data_block[, , t],
      start = c(1, lat_indices[1], t),
      count = c(length(lons), length(lats), 1)
    )
  }

  ncdf4::nc_close(nc_file)
}