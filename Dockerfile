# Script developed by the LCSC-CSIC data team:
# Fergus Reig Gracia <http://fergusreig.es/>; Environmental Hydrology, Climate and Human Activity Interactions, Geoenvironmental Processes, IPE, CSIC <http://www.ipe.csic.es/hidrologia-ambiental/>
# Version: 1.0

# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# any later version.

# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.

# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>
# <http://www.gnu.org/licenses/gpl.txt/>.
#####################################################################

# docker buildx build . --pull -t turc-index

# docker container run --device=/dev/ppp --privileged --name turc-index_calc --cap-add=NET_ADMIN -m 8G --cpus="2" --rm -it -v /mnt/sda2/datos/magi/turc_index_web:/mnt turc-index
# docker container run --device=/dev/ppp --privileged --name turc-index_calc --cap-add=NET_ADMIN -m 8G --cpus="2" --rm -it -v /media/hola/datos:/mnt turc-index
# docker exec --user $(id -u):$(id -g) -it turc-index_calc /bin/bash
# docker exec --user $(id -u):$(id -g) -it turc-index_calc R

FROM ubuntu:24.04

# Set environment variable to suppress interactive prompts
ENV DEBIAN_FRONTEND=noninteractive

RUN apt update && apt install -y patch r-cran-ncdf4 r-cran-terra r-cran-raster r-cran-sf r-cran-dplyr r-cran-abind r-cran-abind
RUN apt install -y python3-cdsapi sudo python3-pip python3.12-venv nano cdo nco
# RUN Rscript -e 'install.packages(c("rPython"), lib="/usr/lib/R/library")'

RUN usermod -aG sudo ubuntu

USER ubuntu
WORKDIR /home/ubuntu

RUN echo 'q <- function(save = "no", status = 0, runLast = TRUE) { .Internal(quit(save, status, runLast)) }' >> ~/.Rprofile
COPY .cdsapirc /home/ubuntu/.cdsapirc
RUN python3 -m venv turc_index_web_env
RUN . turc_index_web_env/bin/activate && pip install "cdsapi>=0.7.2"
RUN echo 'source turc_index_web_env/bin/activate' >> ~/.bashrc