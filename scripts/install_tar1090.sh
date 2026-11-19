#!/bin/bash

# ***** DETENER EL SCRIPT SI HAY UN ERROR *****
set -e

# ***** VERIFICAR QUE SE EJECUTE COMO ROOT *****
if [ "$EUID" -ne 0 ]; then
  echo "Por favor, ejecuta este script como root (sudo)."
  exit 1
fi

echo "Iniciando instalación de tar1090 base..."

# ***** INSTALAR TAR1090 BASE (ESTO CREA LAS DEPENDENCIAS Y LOS ARCHIVOS DE CONFIGURACIÓN) *****
bash -c "$(wget -nv -O - https://github.com/wiedehopf/tar1090/raw/master/install.sh)"

echo "tar1090 base instalado."

# ***** PREGUNTAR POR LA URL DEL REPOSITORIO Y LA RAMA *****
REPO_URL="https://github.com/adsb-vzla/adsb-vzla.git"
REPO_BRANCH="ads-b-vzla-server-deployment"
DEST_DIR="/usr/local/share/tar1090/html"

# ***** RESPALDAR LA CARPETA HTML ORIGINAL SI EXISTE *****
if [ -d "$DEST_DIR" ]; then
    echo "Haciendo respaldo de la carpeta html original..."
    mv "$DEST_DIR" "${DEST_DIR}_backup_$(date +%s)"
fi

# ***** CLONAR TU REPOSITORIO EN LA RAMA ESPECÍFICA *****
echo "Clonando tu repositorio personalizado (rama: $REPO_BRANCH)..."
git clone -b "$REPO_BRANCH" "$REPO_URL" "$DEST_DIR"

echo "¡Instalación completada! Recuerda configurar Nginx o Lighttpd para servir esta carpeta."