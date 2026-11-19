#!/bin/bash

# ***** CONFIGURAR PARA 7 DÍAS *****
DAYS_TO_KEEP=7
HISTORY_DIR="/var/globe_history"

# ***** CALCULAR FECHA LÍMITE (HACE X DÍAS) *****
DATE_LIMIT=$(date -d "-${DAYS_TO_KEEP} days" +%Y/%m/%d)

# ***** BUSCAR Y BORRAR LAS CARPETAS MÁS ANTIGUAS *****
find "$HISTORY_DIR" -mindepth 3 -maxdepth 3 -type d | while read -r folder; do
    # ***** EXTRAER SOLO LA FECHA (AAAA/MM/DD) DE LA RUTA *****
    FOLDER_DATE=$(echo "$folder" | grep -oE '[0-9]{4}/[0-9]{2}/[0-9]{2}$')
    if [ -n "$FOLDER_DATE" ]; then
        # ***** COMPARAR FECHAS Y BORRAR SI ES MÁS ANTIGUA *****
        if [[ "$FOLDER_DATE" < "$DATE_LIMIT" ]]; then
            echo "Deleting old history: $folder"
            rm -rf "$folder"
        fi
    fi
done

# ***** BORRAR CARPETAS VACÍAS *****
find "$HISTORY_DIR" -mindepth 1 -maxdepth 2 -type d -empty -delete

# ***** MENSAJE INFORMATIVO *****
echo "Limpieza de historial completada. Conservando los últimos $DAYS_TO_KEEP días."