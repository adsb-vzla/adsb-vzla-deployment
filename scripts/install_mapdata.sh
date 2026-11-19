#!/bin/bash
set -e

# ***** URL DEL RELEASE DE GITHUB PARA MAPDATA *****
MAPDATA_URL="https://github.com/adsb-vzla/adsb-vzla-deployment/releases/download/mapdata-v0.1/mapdata.zip"

echo "Descargando datos de Mapdata..."
# ***** DESCARGAR A /tmp *****
wget -O /tmp/mapdata.zip "$MAPDATA_URL"

echo "Descomprimiendo en /usr/local/share/..."
# ***** DESCOMPRIMIR (ASEGURANDO QUE LA CARPETA SE CREE) *****
sudo unzip -o /tmp/mapdata.zip -d /usr/local/share/

# ***** LIMPIAR EL ARCHIVO TEMPORAL *****
rm /tmp/mapdata.zip

echo "Mapdata instalado correctamente en /usr/local/share/mapdata/"