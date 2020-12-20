#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail

INGRESS_NGINX_VERSION=3.20.1
METRICS_SERVER_VERSION=5.3.4
KUBE_PROMETHEUS_STACK_VERSION=12.12.1
MINIO_VERSION=8.0.9
LOKI_VERSION=0.22.0
PROMTAIL_VERSION=3.0.1
CANARY_VERSION=0.2.0

main() {
    if [[ -n "${1:-}" ]]; then
        echo '🚀 Updating Loki demo setup...'
        echo

        "setup_${1}"
    else
        echo '🚀 Launching Loki demo setup...'
        echo '⏳ This will roughly take up to 10 minutes...'
        echo

        setup_chart_repos
        setup_cluster
        setup_ingress_nginx
        setup_metrics_server
        setup_monitoring
        setup_minio
        setup_loki
        setup_promtail
        setup_canary
    fi

    echo
    echo '🎉 Done.'
}

setup_chart_repos() {
    echo
    echo '🟡 Adding chart repositories...'
    echo

    helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx --force-update
    helm repo add bitnami https://charts.bitnami.com/bitnami --force-update
    helm repo add grafana https://grafana.github.io/helm-charts --force-update
    helm repo add minio https://helm.min.io --force-update
    helm repo add prometheus-community https://prometheus-community.github.io/helm-charts --force-update

    echo
    echo '✅ Finished adding chart repositories.'
    echo
}

setup_cluster() {
    if ! (kind get clusters | grep --silent loki-minio-demo) &> /dev/null; then
        echo
        echo '🟡 Creating kind cluster...'
        echo

        if ! docker container inspect loki-registry-proxy &> /dev/null; then
            # local pull-through registry
            docker container run --name loki-registry-proxy --net kind --detach \
                --env REGISTRY_PROXY_REMOTEURL=https://registry-1.docker.io \
                registry:2
        fi

        kind create cluster --name=loki-minio-demo --config=config/kind/config.yaml

        echo
        echo '✅ Finished creating kind cluster.'
        echo
    else
        echo
        echo '📣️️ kind cluster already exists. Re-using it!'
        echo
    fi
}

setup_ingress_nginx() {
    log_start ingress-nginx

    helm upgrade ingress-nginx ingress-nginx/ingress-nginx --install --wait \
        --version="$INGRESS_NGINX_VERSION" \
        --namespace=ingress --create-namespace \
        --values=config/ingress-nginx/values.yaml

    log_finished ingress-nginx
}

setup_metrics_server() {
    log_start metrics-server

    helm upgrade metrics-server bitnami/metrics-server --install --wait \
        --version="$METRICS_SERVER_VERSION" \
        --namespace=kube-system \
        --values=config/metrics-server/values.yaml

    log_finished metrics-server
}


setup_monitoring() {
    log_start monitoring

    helm upgrade monitoring prometheus-community/kube-prometheus-stack --install --wait \
        --version="$KUBE_PROMETHEUS_STACK_VERSION" \
        --namespace=monitoring --create-namespace \
        --values=config/monitoring/values.yaml \
        "${dashboard_args[@]}"

    local dashboard_args=()
    local dashboard_path
    for dashboard_path in config/monitoring/dashboards/*.json; do
        local name
        name=$(basename "$dashboard_path")
        name="dashboard-${name%.*}"
        kubectl create configmap "$name" --namespace monitoring --from-file="$dashboard_path" \
            --dry-run=client --output=yaml --save-config | kubectl apply --filename=-
        kubectl label configmap "$name" --namespace=monitoring grafana_dashboard=1 --overwrite
    done

    log_finished monitoring
}

setup_minio() {
    log_start MinIO

    kubectl create namespace minio --dry-run=client --output=yaml --save-config | kubectl apply --filename=-

    if ! kubectl get secret --namespace=minio minio-credentials > /dev/null; then
        kubectl create secret generic --namespace=minio minio-credentials \
            --from-literal=accesskey="$(openssl rand -hex 20)" \
            --from-literal=secretkey="$(openssl rand -hex 40)"
    fi

    helm upgrade minio minio/minio --install --wait \
        --version="$MINIO_VERSION" \
        --namespace=minio \
        --values=config/minio/values.yaml

    log_finished MinIO
}

setup_loki() {
    log_start Loki

    kubectl create namespace loki --dry-run=client --output=yaml --save-config | kubectl apply --filename=-

    local access_key
    access_key=$(kubectl get secret --namespace=minio minio-credentials --output jsonpath="{.data.accesskey}" | base64 --decode)

    local secret_key
    secret_key=$(kubectl get secret --namespace=minio minio-credentials --output=jsonpath="{.data.secretkey}" | base64 --decode)

    kubectl create secret generic minio-credentials --namespace=loki \
        --from-literal=AWS_ACCESS_KEY="$access_key" \
        --from-literal=AWS_SECRET_KEY="$secret_key" \
        --dry-run=client --output=yaml --save-config | kubectl apply --filename=-

    helm upgrade loki grafana/loki-distributed --install --wait --timeout=10m \
        --version="$LOKI_VERSION" \
        --namespace=loki \
        --values=config/loki/values.yaml \
        --set-file=loki.config=config/loki/config.yaml

    log_finished Loki
}

setup_promtail() {
    log_start Promtail

    helm upgrade promtail grafana/promtail --install --wait \
        --version="$PROMTAIL_VERSION" \
        --namespace=loki --create-namespace \
        --values=config/promtail/values.yaml

    log_finished Promtail
}

setup_canary() {
    log_start 'Loki Canary'

    helm upgrade loki-canary grafana/loki-canary --install --wait \
        --version="$CANARY_VERSION" \
        --namespace=loki --create-namespace \
        --values=config/canary/values.yaml

    log_finished 'Loki Canary'
}

log_start() {
    echo
    echo "🟡 Installing $1..."
    echo
}

log_finished() {
    echo
    echo "✅ Finished installing $1."
    echo
}

main "$@"
