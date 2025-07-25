# TURC Index Project

## Overview

The **TURC Index Project** provides a tool for calculating the TURC index using **ERA5-Land** climate data.

## Project Structure

```plaintext
TURC-index/
├── config/
│   └── input_awc_source.txt
├── environment.yml
├── outputs/
│   └── CA_1980_2023.nc
├── preprocessing/
│   ├── AWC_data/
│   │   ├── awc.nc
│   │   ├── era5_land_data.nc
│   │   └── grid_era5_land_standar.nc
│   └── ERA5_land_data/
│       ├── data/
│       └── update_data/
├── scripts/
│   ├── functions.R
│   ├── preprocessing/
│   │   └── generate_awc.R
│   ├── processing/
│   │   ├── download_era5_data.py
│   │   ├── generate_turc_db.sh
│   │   └── main_generate.R
│   └── update/
│       ├── download_new_year.py
│       ├── main_update.R
│       └── update_turc_db.sh
```

## Instructions

### Prerequisites

To execute the processes, you must have Docker installed on your system. Follow the official installation instructions for your operating system:

- **Linux (Docker Engine):** [Docker Engine Installation](https://docs.docker.com/engine/install/)
- **Windows & macOS (Docker Desktop):** [Docker Desktop Installation](https://docs.docker.com/desktop/)

### Configure CDS API

Ensure you have an account on the [Copernicus Climate Data Store](https://cds.climate.copernicus.eu/). Configure the API key by creating a `.cdsapirc` file and save it in the **project root** (`turc_index` folder) to ensure accessibility from the Docker container.

**.cdsapirc content:**

```bash
url: https://cds.climate.copernicus.eu/api
key: <your-api-key>
```

Replace `<your-api-key>` with your Copernicus credentials.

### Generate the Database

1. Clone the repository:

   ```bash
   git clone <REPOSITORY_URL>
   cd turc_index
   ```

2. Build the Docker image:

   ```bash
   docker buildx build . --pull -t turc-index
   ```

3. Run the Docker container:

   ```bash
   docker container run --device=/dev/ppp --privileged --name turc-index_calc --cap-add=NET_ADMIN -m 8G --cpus="2" --rm -it -v /path/to/local/repo:/mnt turc-index
   ```

### Important: Replace `/path/to/local/repo`

Ensure that you replace `/path/to/local/repo` with the absolute path where you cloned this repository. Examples:

- **Linux/macOS**:
  ```bash
  docker container run --device=/dev/ppp --privileged --name turc-index_calc --cap-add=NET_ADMIN -m 8G --cpus="2" --rm -it -v /home/user/projects/turc_index:/mnt turc-index
  ```
- **Windows (Git Bash, WSL, or PowerShell)**:
  ```bash
  docker container run --device=/dev/ppp --privileged --name turc-index_calc --cap-add=NET_ADMIN -m 8G --cpus="2" --rm -it -v /c/Users/user/projects/turc_index:/mnt turc-index
  ```

### Ensure Execution Permissions

Before running the scripts, make sure they have execution permissions:

```bash
chmod +x scripts/processing/generate_turc_db.sh scripts/update/update_turc_db.sh
```

### Running the Docker Container

Once the container is running, you will be inside its interactive shell. From there, you can execute the scripts for creating and updating the database as described below.
To exit the container and return to your system's prompt, type:

```bash
exit
```

or press `Ctrl+D`.

### Create the Turc Index Database

1. Run the script to generate the database:

   ```bash
   cd /mnt/scripts/processing
   bash generate_turc_db.sh start_year end_year
   ```

   **Example:**
   ```bash
   bash generate_turc_db.sh 1980 2023
   ```

   - If you do not provide the start and end years in the command line, you will be prompted to enter them during execution.
   - Ensure the end year is complete with data from January to December.

2. Run the update script:

   ```bash
   cd /mnt/scripts/update
   bash update_turc_db.sh year database_name_to_update
   ```

   **Example:**
   ```bash
   bash update_turc_db.sh 2024 CA_1980_2023.nc
   ```
   
   - If you do not provide the new year and the database name in the command line, you will be prompted to enter them during execution.
   - Ensure the new year is complete with data from January to December.

## Contributions

Contributions are welcome. Please open an issue or submit a pull request to discuss any changes.

## How to Cite

If you use this code, please cite the repository as:

**Franquesa, M., Reig, F. (2025).** *Turc Index Database*. GitHub repository. Available at: [https://github.com/lcsc/turc\_index](https://github.com/lcsc/turc_index)

### BibTeX entry:

```bibtex
@misc{franquesa2025turcindex,
  author = {Franquesa, M. and Reig, F.},
  title = {Turc Index Database: Global calculations based on ERA5-Land data},
  year = {2025},
  url = {https://github.com/lcsc/turc_index},
  note = {Version 1.0. Accessed: YYYY-MM-DD}
}
```

## License

This project is licensed under the **GNU General Public License v3.0 (GPL-3.0)**.

You may copy, distribute, and modify the software as long as you track changes and dates in source files. Any modifications to this project must also be licensed under the GPL-3.0.

A copy of the GNU General Public License is included in this repository. See the [LICENSE](LICENSE) file for more details.

For further information, visit [GNU GPL-3.0](https://www.gnu.org/licenses/gpl-3.0.en.html).

### Licensing Considerations

The **Turc Index Calculation** relies on **ERA5-Land** data from the **Copernicus Climate Data Store**. Users must comply with Copernicus licensing terms. More details: [Copernicus License](https://climate.copernicus.eu/sites/default/files/repository/20170117_Copernicus_License_V1.0.pdf).

