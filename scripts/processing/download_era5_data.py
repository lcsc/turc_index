import cdsapi
import os
import sys

def download_era5_variable(start_year, end_year, output_dir):
    # Crear cliente
    c = cdsapi.Client()

    # Configuración para cada variable
    variables_config = [
        {
            "name": "t2mhourly",
            "dataset": "reanalysis-era5-land-monthly-means",
            "request": {
                "product_type": ["monthly_averaged_reanalysis_by_hour_of_day"],
                "variable": ["2m_temperature"],
                "time": [f"{hour:02d}:00" for hour in range(24)],
                "data_format": "grib",
                "download_format": "unarchived"
            },
        },
        {
            "name": "t2m",
            "dataset": "reanalysis-era5-land-monthly-means",
            "request": {
                "product_type": ["monthly_averaged_reanalysis"],
                "variable": ["2m_temperature"],
                "time": ["00:00"],
                "data_format": "grib",
                "download_format": "unarchived"
            },
        },
        {
            "name": "tdew",
            "dataset": "reanalysis-era5-land-monthly-means",
            "request": {
                "product_type": ["monthly_averaged_reanalysis"],
                "variable": ["2m_dewpoint_temperature"],
                "time": ["00:00"],
                "data_format": "grib",
                "download_format": "unarchived"
            },
        },
        {
            "name": "precipitation",
            "dataset": "reanalysis-era5-land-monthly-means",
            "request": {
                "product_type": ["monthly_averaged_reanalysis_by_hour_of_day"], # https://prod.ecmwf-forum-prod.compute.cci2.ecmwf.int/t/issue-affecting-era5-land-monthly-averaged-reanalysis-for-the-period-september-2022-to-february-2024/2370
                "variable": ["total_precipitation"],
                "time": ["00:00"],
                "data_format": "grib",
                "download_format": "unarchived"
            },
        },
        {
            "name": "solar_radiation",
            "dataset": "reanalysis-era5-land-monthly-means",
            "request": {
                "product_type": ["monthly_averaged_reanalysis_by_hour_of_day"], # https://prod.ecmwf-forum-prod.compute.cci2.ecmwf.int/t/issue-affecting-era5-land-monthly-averaged-reanalysis-for-the-period-september-2022-to-february-2024/2370
                "variable": ["surface_solar_radiation_downwards"],
                "time": ["00:00"],
                "data_format": "grib",
                "download_format": "unarchived"
            },
        },
    ]

    # Crear carpeta de salida
    os.makedirs(output_dir, exist_ok=True)

    # Descargar datos para cada variable
    for config in variables_config:
        output_file = os.path.join(output_dir, f"{config['name']}_{start_year}_{end_year}.grib")
        print(f"Downloading {config['name']} for {start_year}-{end_year}...")

        # Añadir configuración común
        request = config["request"].copy()
        request.update({
            "year": [str(year) for year in range(start_year, end_year + 1)],
            "month": [f"{month:02d}" for month in range(1, 13)],
        })

        # Ejecutar la solicitud
        c.retrieve(config["dataset"], request, output_file)
        print(f"Downloaded {config['name']} for {start_year}-{end_year}: {output_file}")

if __name__ == "__main__":
    if len(sys.argv) != 3:
        print("Uso: python download_era5_data.py <año_inicio> <año_fin>")
        sys.exit(1)

    start_year = int(sys.argv[1])
    end_year = int(sys.argv[2])

    download_era5_variable(start_year, end_year, "../../preprocessing/ERA5_land_data/data")
