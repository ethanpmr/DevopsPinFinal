#!/bin/bash

# Actualizar sistema e instalar Docker
sudo apt-get update
sudo apt-get install -y docker-ce

# Crear volúmenes persistentes
sudo docker volume create nginx_data
sudo docker volume create prometheus_data
sudo docker volume create grafana_data

# Crear una red Docker personalizada
sudo docker network create monitoring

# Descargar y ejecutar NGINX
sudo docker run -d --name nginx --network monitoring -p 80:80 -v nginx_data:/usr/share/nginx/html nginx

# Descargar y ejecutar el exportador de métricas de NGINX
sudo docker run -d --name nginx_exporter --network monitoring -p 9113:9113 nginx/nginx-prometheus-exporter:latest -nginx.scrape-uri=http://nginx:80/stub_status

# Crear el archivo de configuración de Prometheus
cat <<EOF > prometheus.yml
global:
  scrape_interval: 15s

scrape_configs:
  - job_name: 'nginx'
    static_configs:
      - targets: ['nginx_exporter:9113']
EOF

# Descargar y ejecutar Prometheus
sudo docker run -d --name prometheus \
  --network monitoring \
  -p 9090:9090 \
  -v prometheus_data:/prometheus \
  -v $(pwd)/prometheus.yml:/etc/prometheus/prometheus.yml \
  prom/prometheus

# Descargar y ejecutar Grafana
sudo docker run -d --name grafana \
  --network monitoring \
  -p 3000:3000 \
  -v grafana_data:/var/lib/grafana \
  grafana/grafana

# Habilitar Docker para que inicie al arrancar
sudo systemctl enable docker
