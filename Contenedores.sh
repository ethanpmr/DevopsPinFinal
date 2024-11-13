#!/bin/bash
# Script de User Data para ejecutar al lanzar la instancia

# Actualizar paquetes
sudo apt-get update -y

# Instalar Docker
sudo apt-get install -y docker.io

# Iniciar y habilitar Docker
sudo systemctl start docker
sudo systemctl enable docker

# Crear red Docker 'monitoring'
docker network inspect monitoring >/dev/null 2>&1 || \
docker network create monitoring

# Eliminar contenedores existentes (si los hubiera) para evitar conflictos
docker stop prometheus grafana nginx_exporter cadvisor nginx >/dev/null 2>&1
docker rm prometheus grafana nginx_exporter cadvisor nginx >/dev/null 2>&1

# Crear volúmenes persistentes
docker volume create prometheus_data
docker volume create grafana_data
docker volume create nginx_data

# Ejecutar NGINX
docker run -d --name nginx --network monitoring \
  -v nginx_data:/usr/share/nginx/html:ro \
  -p 80:80 nginx

# Ejecutar NGINX Exporter
docker run -d --name nginx_exporter --network monitoring \
  --link nginx -p 9113:9113 \
  nginx/nginx-prometheus-exporter:latest \
  -nginx.scrape-uri=http://nginx:80/stub_status

# Crear archivo prometheus.yml en /home/ubuntu (directorio por defecto)
cat <<EOF > /home/ubuntu/prometheus.yml
global:
  scrape_interval: 15s

scrape_configs:
  - job_name: 'nginx'
    static_configs:
      - targets: ['nginx_exporter:9113']

  - job_name: 'cadvisor'
    static_configs:
      - targets: ['cadvisor:8080']
EOF

# Ejecutar cAdvisor para monitorear contenedores
docker run -d --name cadvisor --network monitoring \
  -p 8080:8080 \
  -v /var/run/docker.sock:/var/run/docker.sock:ro \
  -v /sys:/sys:ro \
  -v /var/lib/docker/:/var/lib/docker:ro \
  gcr.io/cadvisor/cadvisor:latest

# Ejecutar Prometheus
docker run -d --name prometheus --network monitoring \
  -p 9090:9090 \
  -v prometheus_data:/prometheus \
  -v /home/ubuntu/prometheus.yml:/etc/prometheus/prometheus.yml \
  prom/prometheus

# Ejecutar Grafana
docker run -d --name grafana --network monitoring \
  -p 3000:3000 \
  -v grafana_data:/var/lib/grafana \
  grafana/grafana
