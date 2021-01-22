# loki-minio-demo

Demo setup for Grafana Loki in microservices mode using MinIO as storage backend.

## Pre-requisites

The following pre-requisites must be installed:

* [Helm 3](https://helm.sh/)
* [kubectl](https://kubernetes.io/de/docs/tasks/tools/install-kubectl/)
* [Docker](https://www.docker.com/)
* [kind](https://github.com/kubernetes-sigs/kind/)

## Usage

Run `./setup.sh`.
This will create a kind cluster and install all services.

## What's Included?

A kind cluster with one master and three worker nodes is created.
The cluster uses a local pull-through Docker registry for faster image pulling on the various kind nodes and to avoid rate-limiting issue with Docker hub.

The setup creates an _almost_ production-ready, highly available, distributed Loki setup.
However, there are no resources configured for pods in this setup because we have to be able to spin up a lot of pods on a local Docker setup.
You may want to tweak your Docker configuration increasing the number of CPUs and the amount of memory it can use.
In a production setup resources should definitely be configured.

Port 30123 is mapped to the same port on the master node in order to enable ingress.

### The following Helm charts are installed:

* ingress-nginx
* metrics-server
* kube-prometheus-stack
* minio
* loki-distributed
* promtail
* loki-canary

#### Loki is installed with the following components:

* gateway
* ingester
* distributor
* querier
* query-frontend
* table-manager
* compactor
* ruler
* memcached-chunks
* memcached-frontend
* memcached-index-queries

Single-Store (boltdb-shipper) is used for index storage with MinIO as storage backend.

### The following services are reachable via ingress:

* Grafana: http://localhost:30123/grafana
* Prometheus: http://localhost:30123/prom
* Alertmanager: http://localhost:30123/alerts
* MinIO: http://localhost:30123/minio

  MinIO secret key and access keys for logging into the UI can be retrieved with the following commands.
  ```console
  kubectl get secret -n minio minio-credentials -o jsonpath="{.data.secretkey}" | base64 --decode | xargs echo
  kubectl get secret -n minio minio-credentials -o jsonpath="{.data.accesskey}" | base64 --decode | xargs echo
  ```

### Grafana Dashboards

Besides a number of dashboards that come with the kube-prometheus-stack, the following dashboards are provided for Loki:

* Loki Operational (adapted from Grafana's Tanka setup): http://localhost:30123/grafana/d/loki-operational/
* Loki Canary: http://localhost:30123/grafana/d/loki-canary/
