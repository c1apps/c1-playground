#!/bin/bash

set -e

CLUSTER_NAME="$(jq -r '.cluster_name' config.json)"
HOMEASSISTANT_API_KEY="$(jq -r '.services[] | select(.name=="hass") | .api_key' config.json)"
OS="$(uname)"

function create_prometheus_namespace {
  printf '%s' "Create Prometheus namespace"

  echo "---" >>up.log
  # create service
  cat <<EOF | kubectl apply -f - -o yaml | cat >>up.log
apiVersion: v1
kind: Namespace
metadata:
  name: prometheus
EOF
  printf '%s\n' " 🍼"
}

function whitelist_namsspaces {
  printf '%s\n' "whitelist namespaces"

  # whitelist some namespaces
  kubectl label namespace prometheus --overwrite ignoreAdmissionControl=ignore
}

# helm show values prometheus-community/kube-prometheus-stack
function deploy_prometheus {
  ## deploy prometheus
  printf '%s\n' "deploy prometheus"

  mkdir -p overrides
  cat <<EOF >overrides/overrides-prometheus.yml
grafana:
  enabled: true
  adminPassword: operator
  service:
    type: LoadBalancer
prometheusOperator:
  enabled: true
  service:
    type: LoadBalancer
  namespaces:
    releaseNamespace: true
    additional:
    - kube-system
    - smartcheck
    - container-security
    - registry
prometheus:
  enabled: true
  service:
    type: LoadBalancer
  prometheusSpec:
    additionalScrapeConfigs:
    - job_name: api-collector
      scrape_interval: 60s
      scrape_timeout: 30s
      scheme: http
      metrics_path: /
      static_configs:
      - targets: ['api-collector:8000']
    - job_name: smartcheck-metrics
      scrape_interval: 15s
      scrape_timeout: 10s
      scheme: http
      metrics_path: /metrics
      static_configs:
      - targets: ['metrics.smartcheck:8082']
    - job_name: home-assistant
      scrape_interval: 30s
      scrape_timeout: 10s
      scheme: http
      bearer_token: ${HOMEASSISTANT_API_KEY}
      metrics_path: /api/prometheus
      static_configs:
      - targets: ['192.168.1.115:8123']
EOF

  helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
  helm repo add stable https://charts.helm.sh/stable
  helm repo update

  helm upgrade \
    prometheus \
    --values overrides/overrides-prometheus.yml \
    --namespace prometheus \
    --install \
    prometheus-community/kube-prometheus-stack
}

create_prometheus_namespace
whitelist_namsspaces
deploy_prometheus

if [ "${OS}" == 'Linux' ]; then
  ./deploy-proxy.sh prometheus
  ./deploy-proxy.sh grafana
fi