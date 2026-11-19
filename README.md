# ADSB-VZLA Deployment (Infraestructura Docker)

Este repositorio contiene la infraestructura orquestada con Docker para desplegar el sistema ADSB-VZLA. Docker se encargará de levantar el servidor web (Nginx o Lighttpd), el backend de autenticación (Flask) y los servicios de Planes de Vuelo. 

> ⚠️ **IMPORTANTE:** La configuración del hardware, la red (Tailscale), las 4 instancias de `readsb`, el historial (Replay) y los datos geográficos pesados (SRTM, Mapas) **deben realizarse manualmente en el sistema anfitrión (Host)** antes de levantar Docker.

---

## FASE 1: Preparación del Host

### 1.1 Requisitos Básicos y Docker
Asegúrese de tener las dependencias del sistema y Docker instalado.

```bash
# Actualizar sistema e instalar dependencias
sudo apt update
sudo apt install git wget unzip curl python3 python3-pip python3-venv sqlite3 ca-certificates -y

# Instalar Docker (se asume Debian)
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/debian/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/debian $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt update
sudo apt install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin -y
```

### 1.2 Configurar Tailscale y verificar acceso a los receptores

```bash
# Ver estado de Tailscale
tailscale status

# Verificar acceso a los puertos de datos (30005) de todos los receptores
nc -zv <IP_RECEPTOR_A> 30005
nc -zv <IP_RECEPTOR_B> 30005
nc -zv <IP_RECEPTOR_C> 30005
nc -zv <IP_RECEPTOR_D> 30005
```

### 1.3 Clonar repositorios y preparar carpetas

Antes de configurar los servicios, clone los repositorios y prepare los directorios base.

```bash
# Crear directorios base
sudo mkdir -p /var/globe_history
sudo mkdir -p /usr/local/share/tar1090/html
sudo mkdir -p /usr/local/share/mapdata

# Permisos para el historial
sudo chown readsb:nogroup /var/globe_history
sudo chmod 755 /var/globe_history

# Clonar la infraestructura de Docker
git clone https://github.com/adsb-vzla/adsb-vzla-deployment.git
cd adsb-vzla-deployment

# Clonar el repositorio de Flight Plans (Django)
git clone https://github.com/adsb-vzla/flight-plans.git

# Clonar el repositorio de ADSB-VZLA
REPO_URL="https://github.com/adsb-vzla/adsb-vzla.git"
REPO_BRANCH="ads-b-vzla-server-deployment"
DEST_DIR="/usr/local/share/tar1090/html"

if [ -d "$DEST_DIR" ]; then
    sudo mv "$DEST_DIR" "${DEST_DIR}_backup_$(date +%s)"
fi
sudo git clone -b "$REPO_BRANCH" "$REPO_URL" "$DEST_DIR"
```

### 1.4 Configurar las 4 instancias de readsb (con Replay)
Docker no maneja la radiofrecuencia. Detenga el servicio base, cree las 4 instancias y añada los puertos de Replay.

```bash
# Detener servicio base
sudo systemctl stop readsb
sudo systemctl disable readsb

# Copiar plantillas de servicio
sudo cp /lib/systemd/system/readsb.service /etc/systemd/system/readsb-a.service
sudo cp /lib/systemd/system/readsb.service /etc/systemd/system/readsb-b.service
sudo cp /lib/systemd/system/readsb.service /etc/systemd/system/readsb-c.service
sudo cp /lib/systemd/system/readsb.service /etc/systemd/system/readsb-d.service
```

#### Receptor A
Edite sudo nano /etc/systemd/system/readsb-a.service y coloque:

```bash
[Service]
RuntimeDirectory=readsb-a
ExecStart=/usr/bin/readsb --net-only \
  --net-connector <IP_RECEPTOR_A>,30005,beast_in \
  --net-bo-port 31005 \
  --write-json /run/readsb-a \
  --write-json-every 1 \
  --lat 10.423611 --lon -67.207778 \
  --db-file /usr/local/share/tar1090/aircraft.csv.gz \
  --quiet
```

#### Receptor B
Edite sudo nano /etc/systemd/system/readsb-b.service y coloque:

```bash
[Service]
RuntimeDirectory=readsb-b
ExecStart=/usr/bin/readsb --net-only \
  --net-connector <IP_RECEPTOR_B>,30005,beast_in \
  --net-bo-port 31006 \
  --write-json /run/readsb-b \
  --write-json-every 1 \
  --lat 10.423611 --lon -67.207778 \
  --db-file /usr/local/share/tar1090/aircraft.csv.gz \
  --quiet
```

#### Receptor C
Edite sudo nano /etc/systemd/system/readsb-c.service y coloque:

```bash
[Service]
RuntimeDirectory=readsb-c
ExecStart=/usr/bin/readsb --net-only \
  --net-connector <IP_RECEPTOR_C>,30005,beast_in \
  --net-bo-port 31007 \
  --write-json /run/readsb-c \
  --write-json-every 1 \
  --lat 10.423611 --lon -67.207778 \
  --db-file /usr/local/share/tar1090/aircraft.csv.gz \
  --quiet
```

#### Receptor D
Edite sudo nano /etc/systemd/system/readsb-d.service y coloque:

```bash
[Service]
RuntimeDirectory=readsb-d
ExecStart=/usr/bin/readsb --net-only \
  --net-connector <IP_RECEPTOR_D>,30005,beast_in \
  --net-bo-port 31008 \
  --write-json /run/readsb-d \
  --write-json-every 1 \
  --lat 10.423611 --lon -67.207778 \
  --db-file /usr/local/share/tar1090/aircraft.csv.gz \
  --quiet
```

Habilite y arranque los servicios:

```bash
sudo systemctl daemon-reload
sudo systemctl enable readsb-a readsb-b readsb-c readsb-d
sudo systemctl start readsb-a readsb-b readsb-c readsb-d
```

### 1.5 Configurar el servicio de Replay

Cree el servicio de agregación de historial:

```bash
sudo nano /etc/systemd/system/readsb-replay.service
```

Pegue el siguiente contenido:

```bash
[Unit]
Description=readsb replay history aggregator
After=network.target readsb-a.service readsb-b.service readsb-c.service readsb-d.service
Requires=readsb-a.service readsb-b.service readsb-c.service readsb-d.service

[Service]
Type=simple
User=readsb
Group=nogroup
Restart=always
RestartSec=5
ExecStart=/usr/bin/readsb --net-only \
  --net-connector <IP_SERVIDOR>,31005,beast_in \
  --net-connector <IP_SERVIDOR>,31006,beast_in \
  --net-connector <IP_SERVIDOR>,31007,beast_in \
  --net-connector <IP_SERVIDOR>,31008,beast_in \
  --write-globe-history /var/globe_history \
  --heatmap 30 \
  --lat 10.423611 --lon -67.207778 \
  --db-file /usr/local/share/tar1090/aircraft.csv.gz \
  --quiet

[Install]
WantedBy=multi-user.target
```

Active el servicio:

```bash
sudo systemctl daemon-reload
sudo systemctl enable readsb-replay.service
sudo systemctl start readsb-replay.service
```

### 1.6 Programar limpieza de historial (Cron)

Copie el script de limpieza y prográmelo:

```bash
sudo cp scripts/clean_history.sh /usr/local/bin/
sudo chmod +x /usr/local/bin/clean_history.sh
sudo crontab -e
```

Añada al final del archivo:

```bash
0 3 * * * /usr/local/bin/clean_history.sh >> /var/log/history_cleanup.log 2>&1
```

### 1.7 Crear archivos compartidos y enlaces simbólicos

Ahora que la carpeta /html existe (por el clonado), cree los enlaces y el archivo receiver.json:

```bash
# Dar permisos a los archivos de los receptores
sudo chmod -R 755 /run/readsb-a /run/readsb-b /run/readsb-c /run/readsb-d

# Crear enlaces simbólicos
sudo ln -sf /run/readsb-a /usr/local/share/tar1090/html/data-receiver-a
sudo ln -sf /run/readsb-b /usr/local/share/tar1090/html/data-receiver-b
sudo ln -sf /run/readsb-c /usr/local/share/tar1090/html/data-receiver-c
sudo ln -sf /run/readsb-d /usr/local/share/tar1090/html/data-receiver-d

# Crear archivo receiver.json
sudo mkdir -p /usr/local/share/tar1090/html/data
sudo tee /usr/local/share/tar1090/html/data/receiver.json > /dev/null << 'EOF'
{
  "version": "readsb",
  "refresh": 1000,
  "history": 0,
  "lat": 10.423611,
  "lon": -67.207778,
  "site_name": "ADS-B VZLA",
  "binCraft": false,
  "zstd": false
}
EOF
```

### 💡 Alternativa: simulación de receptores (Para pruebas locales)

Si desea probar la instalación de Docker en una máquina que **no tiene acceso a los receptores físicos ni a Tailscale** (por ejemplo, una laptop con WSL o una VM), puede simular los datos de los receptores creando archivos falsos. Esto le permitirá verificar que el mapa, el login y los contenedores funcionan correctamente.

Ejecute los siguientes comandos en la máquina de prueba para crear la estructura y archivos JSON vacíos:

```bash
# Crear las carpetas en la RAM (simulando readsb)
sudo mkdir -p /run/readsb-a /run/readsb-b /run/readsb-c /run/readsb-d

# Crear archivos JSON falsos pero válidos para que tar1090 no falle
for i in a b c d; do
  echo '{"now": 123456789, "messages": 0, "aircraft": []}' | sudo tee /run/readsb-$i/aircraft.json
done

# Dar permisos de lectura a Docker
sudo chmod -R 755 /run/readsb-a /run/readsb-b /run/readsb-c /run/readsb-d

# Crear la carpeta html (si no la ha clonado) y los enlaces simbólicos
sudo mkdir -p /usr/local/share/tar1090/html
sudo ln -sf /run/readsb-a /usr/local/share/tar1090/html/data-receiver-a
sudo ln -sf /run/readsb-b /usr/local/share/tar1090/html/data-receiver-b
sudo ln -sf /run/readsb-c /usr/local/share/tar1090/html/data-receiver-c
sudo ln -sf /run/readsb-d /usr/local/share/tar1090/html/data-receiver-d

# Crear archivo receiver.json básico
sudo mkdir -p /usr/local/share/tar1090/html/data
sudo tee /usr/local/share/tar1090/html/data/receiver.json > /dev/null << 'EOF'
{
  "version": "readsb",
  "refresh": 1000,
  "history": 0,
  "lat": 10.423611,
  "lon": -67.207778,
  "site_name": "ADS-B VZLA (Simulación)",
  "binCraft": false,
  "zstd": false
}
EOF
```

Después de ejecutar esto, puede continuar con la Fase 2 (Instalación de Docker). El sistema levantará los contenedores correctamente, podrá iniciar sesión y ver el mapa. La lista de aeronaves estará vacía, pero confirmará que toda la infraestructura de software está operativa.

## FASE 2: Instalación de Docker

Una vez preparado el host, levante los contenedores.

### 1. Ejecutar el instalador (elija Nginx o Lighttpd)

```bash
# Para Nginx
sudo bash setup-nginx.sh

# O para Lighttpd
sudo bash setup-lighttpd.sh
```

El script hará automáticamente lo siguiente:

- Descargar el SRTM y Mapdata desde los Releases de GitHub.
- Descargar los mapas offline (Tiles).
- Construir y levantar los contenedores de Docker.

### 2. Inicializar la Base de Datos de Flask (solo la primera vez)

```bash
sudo docker compose -f docker-compose.nginx.yml exec auth python init_db.py
```

### 3. Aplicar migraciones en Flight Plans (solo la primera vez)

```bash
sudo docker compose -f docker-compose.nginx.yml exec flight-plans python manage.py migrate
```

## FASE 3: Integración de Flight Plans (API)

Para que tar1090 consulte los planes de vuelo, genere un token.

### 1. Generar el Token

```bash
cd flight-plans
sudo docker compose exec -T web python manage.py shell -c "from django.contrib.auth import get_user_model; from rest_framework.authtoken.models import Token; user = get_user_model().objects.get(username='adsbvzla'); token, _ = Token.objects.get_or_create(user=user); print(token.key)"
```

### 2. Configurar el Frontend:
Edite el archivo de configuración de tar1090 (en el host):

```bash
sudo nano /usr/local/share/tar1090/html/static/js/flight-plans.js
```

Actualice el API_TOKEN y el API_URL:

```bash
const API_URL = 'http://<DOMINIO_O_IP_DEL_RECEPTOR>/flight_plans/api/flights/';
const API_TOKEN = 'TU_TOKEN_GENERADO_AQUI';
```

## Notas Críticas y Solución de Problemas

- Enlaces Simbólicos: si el mapa no muestra aviones, verique que los enlaces (data-receiver-a, etc.) existan en /usr/local/share/tar1090/html/. Docker lee esa carpeta, pero los enlaces deben ser creados en el host.

- Permisos de Nginx: si usa Nginx en el host y ve errores de "Permiso Denegado" en los mapas, asegúrese de ejecutar sudo chown -R www-data:www-data /opt/srtm/ y sudo chmod -R 755 /usr/local/share/osm_tiles_offline/.

- Historial (Replay): los datos históricos se guardan en /var/globe_history. El script de limpieza (cron) borrará automáticamente los datos de más de 7 días.

