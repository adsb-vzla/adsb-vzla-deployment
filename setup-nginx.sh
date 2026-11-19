#!/bin/bash
set -e

# ***** VERIFICAR QUE SE EJECUTE COMO ROOT (O CON SUDO) *****
if [ "$EUID" -ne 0 ]; then
  echo "Por favor, ejecuta este script con sudo: sudo bash setup-nginx.sh"
  exit 1
fi

echo "====================================================="
echo "   INICIANDO INSTALACIÓN DE ADSB-VZLA (NGINX)        "
echo "====================================================="

# ***** PASO 1: INSTALAR DEPENDENCIAS BÁSICAS *****
echo "Paso 1: Instalando dependencias (git, wget, unzip, docker)..."
apt update
apt install -y git wget unzip curl
# (Asumimos que Docker ya está instalado en el sistema)

# ***** PASO 2: DESCARGAR DATOS PESADOS (SRTM Y MAPDATA) *****
echo "Paso 2: Descargando SRTM y Mapdata..."
bash scripts/install_srtm.sh
bash scripts/install_mapdata.sh

# ***** PASO 3: INSTALAR MAPAS OFFLINE (TILES) *****
echo "Paso 3: Descargando Tiles de OpenStreetMap..."
bash scripts/install_tiles.sh

# ***** PASO 4: CLONAR TAR1090 PERSONALIZADO *****
echo "Paso 4: Clonando tu repositorio de tar1090..."
REPO_URL="https://github.com/adsb-vzla/adsb-vzla.git"
REPO_BRANCH="ads-b-vzla-server-deployment"
DEST_DIR="/usr/local/share/tar1090/html"

if [ -d "$DEST_DIR" ]; then
    echo "La carpeta $DEST_DIR ya existe. Haciendo respaldo..."
    mv "$DEST_DIR" "${DEST_DIR}_backup_$(date +%s)"
fi
git clone -b "$REPO_BRANCH" "$REPO_URL" "$DEST_DIR"

# ***** PASO 5: CLONAR FLIGHT PLANS *****
echo "Paso 5: Clonando Flight Plans..."
if [ ! -d "./flight-plans" ]; then
    git clone https://github.com/adsb-vzla/flight-plans.git
else
    echo "La carpeta flight-plans ya existe, saltando clonado."
fi

# ***** PASO 6: CONSTRUIR Y LEVANTAR DOCKER (NGINX) *****
echo "Paso 6: Levantando los contenedores de Docker (Nginx)..."
docker compose -f docker-compose.nginx.yml up -d --build

echo "====================================================="
echo "   INSTALACIÓN COMPLETADA CON ÉXITO                  "
echo "   Accede al sistema en: http://[IP_DEL_RECEPTOR]/SVZM/"
echo "====================================================="