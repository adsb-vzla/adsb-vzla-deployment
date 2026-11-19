#!/bin/bash
set -e

# ***** URL DEL RELEASE DE GITHUB *****
SRTM_URL="https://github.com/adsb-vzla/adsb-vzla-deployment/releases/download/srtm-v0.1/srtm.zip"

echo "Descargando datos de elevación SRTM..."
# ***** DESCARGAR A /tmp *****
wget -O /tmp/srtm.zip "$SRTM_URL"

echo "Descomprimiendo en /opt/..."
# ***** DESCOMPRIMIR (ASEGURANDO QUE LA CARPETA /opt/srtm SE CREE) *****
sudo unzip -o /tmp/srtm.zip -d /opt/

# ***** LIMPIAR EL ARCHIVO TEMPORAL *****
rm /tmp/srtm.zip

echo "SRTM instalado correctamente en /opt/srtm/"