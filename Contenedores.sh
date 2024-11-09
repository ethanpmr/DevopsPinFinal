#!/bin/bash

# Actualizar sistema e instalar Docker
sudo apt-get update
sudo apt-get install -y docker-ce
#!/bin/bash

# Crear red Docker 'monitoring' si no existe
docker network inspect monitoring >/dev/null 2>&1 || \
docker network create monitoring


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

# Crear archivo prometheus.yml
cat <<EOF > prometheus.yml
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
  -v $(pwd)/prometheus.yml:/etc/prometheus/prometheus.yml \
  prom/prometheus

# Ejecutar Grafana
docker run -d --name grafana --network monitoring \
  -p 3000:3000 \
  -v grafana_data:/var/lib/grafana \
  grafana/grafana

# Habilitar Docker para que inicie al arrancar
sudo systemctl enable docker
