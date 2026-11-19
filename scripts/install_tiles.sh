#!/bin/bash

# ***** DETENER EL SCRIPT SI HAY UN ERROR *****
set -e

echo "Descargando tiles base de OpenStreetMap (700 MB)..."
curl -s https://raw.githubusercontent.com/wiedehopf/adsb-scripts/master/osm_tiles_offline.sh | sudo bash

echo "Descargando tiles de mayor detalle (1.3 GB)..."
curl -s https://raw.githubusercontent.com/wiedehopf/adsb-scripts/master/osm_tiles_offline_10.sh | sudo bash

echo "¡Mapas offline instalados correctamente!"