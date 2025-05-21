#!/bin/bash

# Check if the script received exactly two arguments
if [ "$#" -eq 2 ]; then
  # Assign command-line arguments to variables
    start_year=$1
    end_year=$2
    # Display the input years
    echo "Start year: $start_year"
    echo "End year: $end_year"
else
    # Request the start and end years from the user
    echo "Enter the start year:"
    read start_year
    echo "Enter the end year:"
    read end_year
fi

# Validate the years
if ! [[ "$start_year" =~ ^[0-9]{4}$ ]] || ! [[ "$end_year" =~ ^[0-9]{4}$ ]]; then
    echo "Error: You must enter valid years (format: YYYY)."
    exit 1
fi

if [ "$start_year" -gt "$end_year" ]; then
    echo "Error: The start year cannot be greater than the end year."
    exit 1
fi

# Define the preprocessing start year (one year before the start year)
pre_start_year=$((start_year - 1))

# Directories and configurations
BASE_DIR="../../preprocessing/ERA5_land_data/data"
if [ ! -d "$BASE_DIR" ]; then
    echo "Creating BASE_DIR: $BASE_DIR"
    mkdir -p "$BASE_DIR"
fi

# Output file for the database
TEMP_FILE="../../outputs/CA_${pre_start_year}_${end_year}.nc"

OUTPUT_db_NAME="../../outputs/CA_${start_year}_${end_year}.nc"

# 1. Download data for the year range (including pre_start_year)
echo "Downloading data..."
python3 download_era5_data.py $pre_start_year $end_year || { echo "Error: Download failed."; exit 1; }

# 2. Process downloaded data

# Process mean temperature
echo "Processing mean temperature..."
cdo -L -f nc -setname,tmean -setunit,"Celsius" -subc,273.15 "$BASE_DIR/t2m_${pre_start_year}_${end_year}.grib" "$BASE_DIR/tmean_${pre_start_year}_${end_year}.nc"

# Process minimum temperature
echo "Processing minimum temperature..."
cdo -L -f nc -setname,tmin -setunit,"Celsius" -subc,273.15 -monmin "$BASE_DIR/t2mhourly_${pre_start_year}_${end_year}.grib" "$BASE_DIR/tmin_bnds_${pre_start_year}_${end_year}.nc"
ncks -C -x -v time_bnds "$BASE_DIR/tmin_bnds_${pre_start_year}_${end_year}.nc" -o "$BASE_DIR/tmin_${pre_start_year}_${end_year}.nc"
rm "$BASE_DIR/tmin_bnds_${pre_start_year}_${end_year}.nc"

# Process relative humidity
echo "Processing relative humidity..."
cdo -L -f nc expr,'es=0.6108*exp((17.27*(2t-273.15))/((2t-273.15)+237.3))' "$BASE_DIR/t2m_${pre_start_year}_${end_year}.grib" "$BASE_DIR/es_${pre_start_year}_${end_year}.nc"
cdo -L -f nc expr,'ea=0.6108*exp((17.27*(2d-273.15))/((2d-273.15)+237.3))' "$BASE_DIR/tdew_${pre_start_year}_${end_year}.grib" "$BASE_DIR/ea_${pre_start_year}_${end_year}.nc"
cdo -L -f nc expr,'rh=(ea/es)*100' -merge "$BASE_DIR/ea_${pre_start_year}_${end_year}.nc" "$BASE_DIR/es_${pre_start_year}_${end_year}.nc" "$BASE_DIR/rh_${pre_start_year}_${end_year}.nc"
rm "$BASE_DIR/es_${pre_start_year}_${end_year}.nc"
rm "$BASE_DIR/ea_${pre_start_year}_${end_year}.nc"

# Process solar radiation
echo "Processing solar radiation..."
cdo -f nc -setname,ssrd -setunit,"J m**-2" "$BASE_DIR/solar_radiation_${pre_start_year}_${end_year}.grib" "$BASE_DIR/solar_radiation_temp_${pre_start_year}_${end_year}.nc"
cdo setattribute,ssrd@long_name="Surface solar radiation downwards" "$BASE_DIR/solar_radiation_temp_${pre_start_year}_${end_year}.nc" "$BASE_DIR/solar_radiation_${pre_start_year}_${end_year}.nc"
rm "$BASE_DIR/solar_radiation_temp_${pre_start_year}_${end_year}.nc"

# Process precipitation
echo "Processing precipitation..."
cdo -f nc -setname,tp -setunit,"m" "$BASE_DIR/precipitation_${pre_start_year}_${end_year}.grib" "$BASE_DIR/precipitation_temp_${pre_start_year}_${end_year}.nc"
cdo setattribute,tp@long_name="Total precipitation" "$BASE_DIR/precipitation_temp_${pre_start_year}_${end_year}.nc" "$BASE_DIR/precipitation_${pre_start_year}_${end_year}.nc"
rm "$BASE_DIR/precipitation_temp_${pre_start_year}_${end_year}.nc"

# Remove GRIB files
echo "Cleaning up GRIB files..."
# rm "$BASE_DIR"/*.grib

# Execute the main script to consolidate the database
echo "Running main script to consolidate the database..."
Rscript main_generate.R $pre_start_year $end_year

# Remove temporary NetCDF files
echo "Cleaning up temporary NetCDF files..."
# rm "$BASE_DIR"/*.nc

# Post-processing steps
echo "Processing the final output..."
cdo -z zip_9 -settime,00:00:00 -sellonlatbox,-180,180,-90,90 -invertlat -delete,timestep=1/12 "$TEMP_FILE" "$OUTPUT_db_NAME"

# Remove the temporary file
# rm "$TEMP_FILE"

# Final message
echo "Final file created: CA_${start_year}_${end_year}.nc"
echo "Done."
