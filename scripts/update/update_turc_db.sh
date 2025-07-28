#!/bin/bash

# Activate Python env
source ~/turc_index_web_env/bin/activate

# Check if the script received exactly two arguments
if [ "$#" -eq 2 ]; then
  # Assign command-line arguments to variables
    year=$1
    db_name=$2
    # Display the input years
    echo "The year you want to update: $year"
    echo "The database name to update: $db_name"
else
    # Request the year from the user
    echo "Enter the year you want to update:"
    read year

    # Request the database name from the user
    echo "Enter the database name to update:"
    read db_name
fi

# Validate the year
if ! [[ "$year" =~ ^[0-9]{4}$ ]]; then
    echo "Error: You must enter a valid year (format: YYYY)"
    exit 1
fi

# Validate the database name
if ! [[ "$db_name" =~ ^CA_[0-9]{4}_[0-9]{4}\.nc$ ]]; then
    echo "Error: The database name must follow the format CA_<start_year>_<end_year>.nc"
    exit 1
fi

# Extract start and end years from db_name
start_year=$(echo $db_name | sed -E 's/^CA_([0-9]{4})_[0-9]{4}\.nc$/\1/')
end_year=$(echo $db_name | sed -E 's/^CA_[0-9]{4}_([0-9]{4})\.nc$/\1/')

# Check if the year to update is the next in sequence
if [[ $year -ne $((end_year + 1)) ]]; then
    echo "Error: The year to update must be one year after the current database's end year ($end_year)"
    exit 1
fi

# Define the preprocessing start year (one year before the year to update)
pre_year=$((year - 1))

# Directories and configurations
BASE_DIR="../../preprocessing/ERA5_land_data/update_data"
if [ ! -d "$BASE_DIR" ]; then
    echo "Creating BASE_DIR: $BASE_DIR"
    mkdir -p "$BASE_DIR"
fi

# Temporary output file for the new year's data
TEMP_OUTPUT="../../outputs/CA_${pre_year}_${year}.nc"

# Updated database name
FINAL_DB_NAME="../../outputs/CA_${start_year}_${year}.nc"

# Step 1: Download data for the year range (including pre_year)
echo "Downloading data for years $pre_year to $year..."
python3 download_new_year.py $pre_year $year

# Step 2: Preprocess the downloaded data

# Process mean temperature
echo "Processing mean temperature..."
cdo -L -f nc -setname,tmean -setunit,"Celsius" -subc,273.15 "$BASE_DIR/t2m_${pre_year}_${year}.grib" "$BASE_DIR/tmean_${pre_year}_${year}.nc"

# Process minimum temperature
echo "Processing minimum temperature..."

cdo -L -f nc -setname,tmin -setunit,"Celsius" -subc,273.15 -monmin "$BASE_DIR/t2mhourly_${pre_year}_${year}.grib" "$BASE_DIR/tmin_bnds_${pre_year}_${year}.nc"
ncks -O -C -x -v time_bnds "$BASE_DIR/tmin_bnds_${pre_year}_${year}.nc" -o "$BASE_DIR/tmin_${pre_year}_${year}.nc"
rm "$BASE_DIR/tmin_bnds_${pre_year}_${year}.nc"

echo "Processing relative humidity..."
cdo -L -f nc expr,'es=0.6108*exp((17.27*(2t-273.15))/((2t-273.15)+237.3))' "$BASE_DIR/t2m_${pre_year}_${year}.grib" "$BASE_DIR/es_${pre_year}_${year}.nc"
cdo -L -f nc expr,'ea=0.6108*exp((17.27*(2d-273.15))/((2d-273.15)+237.3))' "$BASE_DIR/tdew_${pre_year}_${year}.grib" "$BASE_DIR/ea_${pre_year}_${year}.nc"
cdo -L -f nc expr,'rh=(ea/es)*100' -merge "$BASE_DIR/ea_${pre_year}_${year}.nc" "$BASE_DIR/es_${pre_year}_${year}.nc" "$BASE_DIR/rh_${pre_year}_${year}.nc"
rm "$BASE_DIR/es_${pre_year}_${year}.nc"
rm "$BASE_DIR/ea_${pre_year}_${year}.nc"

echo "Processing solar radiation..."
cdo -f nc -setname,ssrd -setunit,"J m**-2" "$BASE_DIR/solar_radiation_${pre_year}_${year}.grib" "$BASE_DIR/solar_radiation_temp_${pre_year}_${year}.nc"
cdo setattribute,ssrd@long_name="Surface solar radiation downwards" "$BASE_DIR/solar_radiation_temp_${pre_year}_${year}.nc" "$BASE_DIR/solar_radiation_${pre_year}_${year}.nc"
rm "$BASE_DIR/solar_radiation_temp_${pre_year}_${year}.nc"

echo "Processing precipitation..."
cdo -f nc -setname,tp -setunit,"m" "$BASE_DIR/precipitation_${pre_year}_${year}.grib" "$BASE_DIR/precipitation_temp_${pre_year}_${year}.nc"
cdo setattribute,tp@long_name="Total precipitation" "$BASE_DIR/precipitation_temp_${pre_year}_${year}.nc" "$BASE_DIR/precipitation_${pre_year}_${year}.nc"
rm "$BASE_DIR/precipitation_temp_${pre_year}_${year}.nc"

# Remove GRIB files
rm "$BASE_DIR"/*.grib

# Run the main update script with the year and database name
Rscript main_update.R $pre_year $year

# Remove NetCDF files
rm "$BASE_DIR"/*.nc

echo "Processing new data..."
cdo -z zip_9 -settime,00:00:00 -sellonlatbox,-180,180,-90,90 -invertlat -delete,timestep=1/12 "$TEMP_OUTPUT" "${TEMP_OUTPUT%.nc}_processed.nc"

echo "Merging new data with the existing database..."
cdo mergetime "../../outputs/$db_name" "${TEMP_OUTPUT%.nc}_processed.nc" "${TEMP_OUTPUT%.nc}_merged.nc"
rm "${TEMP_OUTPUT%.nc}_processed.nc"

echo "Compressing the updated database..."
cdo -z zip_9 copy "${TEMP_OUTPUT%.nc}_merged.nc" "$FINAL_DB_NAME"
rm "${TEMP_OUTPUT%.nc}_merged.nc"
rm "$TEMP_OUTPUT"

echo "Database updated successfully: $FINAL_DB_NAME"
