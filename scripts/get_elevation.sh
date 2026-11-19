#!/bin/bash
set -u

# ***** RUTA AL ARCHIVO VRT *****
VRT_PATH="/opt/srtm/venezuela/venezuela.vrt"

python3 - "$VRT_PATH" <<'PY'
import json
import math
import os
import sys
import urllib.parse

# ***** FUNCIÓN PARA DEVOLVER EL ESTADO HTTP *****
def http_status(code):
    return {200: "OK", 400: "Bad Request", 500: "Internal Server Error"}.get(code, "OK")

# ***** FUNCIÓN PARA IMPRIMIR EL JSON DE RESPUESTA *****
def emit_json(payload, status=200):
    print(f"Status: {status} {http_status(status)}")
    print("Content-Type: application/json")
    print("")
    print(json.dumps(payload))
    sys.exit(0)

# ***** FUNCIÓN PARA PARSEAR LOS PARÁMETROS DE LA URL *****
def parse_query():
    qs = os.environ.get("QUERY_STRING", "")
    params = {}
    for part in qs.split("&"):
        if "=" not in part:
            continue
        k, v = part.split("=", 1)
        params[urllib.parse.unquote(k)] = urllib.parse.unquote(v)
    return params

# ***** FUNCIÓN PARA CALCULAR DISTANCIA (HAVERSINE) *****
def haversine_km(lat1, lon1, lat2, lon2):
    R = 6371.0
    lat1 = math.radians(lat1)
    lon1 = math.radians(lon1)
    lat2 = math.radians(lat2)
    lon2 = math.radians(lon2)
    dlat = lat2 - lat1
    dlon = lon2 - lon1
    a = math.sin(dlat / 2) ** 2 + math.cos(lat1) * math.cos(lat2) * math.sin(dlon / 2) ** 2
    c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a))
    return R * c

# ***** IMPORTAR GDAL *****
try:
    from osgeo import gdal
    gdal.UseExceptions()
except Exception as e:
    emit_json({"error": f"GDAL no disponible: {e}", "points": []}, 500)

# ***** FUNCIÓN PARA MUESTREAR LA ELEVACIÓN *****
def sample_elevation(ds, lat, lon):
    band = ds.GetRasterBand(1)
    gt = ds.GetGeoTransform()
    if gt is None:
        raise RuntimeError("El raster no tiene geotransformación")
    xpix = (lon - gt[0]) / gt[1]
    ypix = (lat - gt[3]) / gt[5]
    x0 = int(math.floor(xpix))
    y0 = int(math.floor(ypix))
    xf = xpix - x0
    yf = ypix - y0
    x0 = max(0, min(ds.RasterXSize - 2, x0))
    y0 = max(0, min(ds.RasterYSize - 2, y0))
    block = band.ReadAsArray(x0, y0, 2, 2)
    if block is None:
        return None
    if block.ndim == 1:
        block = block.reshape((1, 1))
    a = float(block[0, 0])
    b = float(block[0, 1] if block.shape[1] > 1 else block[0, 0])
    c = float(block[1, 0] if block.shape[0] > 1 else block[0, 0])
    d = float(block[1, 1] if block.shape[0] > 1 and block.shape[1] > 1 else block[0, 0])
    nd = band.GetNoDataValue()
    if nd is None:
        nd = -32768
    for v in (a, b, c, d):
        if v == nd or v <= -32760:
            return None
    top = a * (1 - xf) + b * xf
    bottom = c * (1 - xf) + d * xf
    return top * (1 - yf) + bottom * yf

# ***** EJECUCIÓN PRINCIPAL *****
try:
    params = parse_query()
    lat1 = float(params.get("lat1", "0"))
    lon1 = float(params.get("lon1", "0"))
    lat2 = float(params.get("lat2", "0"))
    lon2 = float(params.get("lon2", "0"))
    samples = max(2, int(params.get("samples", "20")))
    vrt_path = sys.argv[1] if len(sys.argv) > 1 else VRT_PATH
    ds = gdal.OpenEx(vrt_path, gdal.OF_RASTER)
    if ds is None:
        emit_json({"error": f"No se pudo abrir el VRT: {vrt_path}", "points": []}, 500)
    points = []
    prev_lat, prev_lon = lat1, lon1
    total_nm = 0.0
    for i in range(samples):
        t = i / (samples - 1) if samples > 1 else 0.0
        lat = lat1 + (lat2 - lat1) * t
        lon = lon1 + (lon2 - lon1) * t
        if i > 0:
            total_nm += haversine_km(prev_lat, prev_lon, lat, lon) / 1.852
        elev = sample_elevation(ds, lat, lon)
        points.append({
            "lat": lat,
            "lon": lon,
            "distNm": round(total_nm, 6),
            "alt": (float(elev) if elev is not None else None)
        })
        prev_lat, prev_lon = lat, lon
    emit_json({"points": points, "totalNm": round(total_nm, 6)}, 200)
except Exception as e:
    emit_json({"error": f"Error inesperado: {e}", "points": []}, 500)
PY