# [Healenium.io](http://Healenium.io) on Kubernetes


[![Docker Pulls](https://img.shields.io/docker/pulls/healenium/hlm-backend.svg?maxAge=25920)](https://hub.docker.com/u/healenium)
[![License](https://img.shields.io/badge/license-Apache-brightgreen.svg)](https://www.apache.org/licenses/LICENSE-2.0)

### Table of Contents

[Overall information](#overall-information)

[Minikube installation](#minikube)
* [Prerequisites](#prerequisites)
* [Run Healeniuml in Minikube](#run-healenium-in-minikube)

### Overall information

This project is created to install Healenium on Kubernetes with Helm.

It is suitable to both language agnostic solution [Healenium-Proxy](https://github.com/healenium/healenium) which able to use all selenium supported languages like Java/Python/JS/C# and exclusively Java tests based on [Healenium-Web](https://github.com/healenium/healenium-web) lib.

It describes installation of all mandatory services to run the application.


#### The chart includes the following configuration files:

-  Deployments and Service files of: `Hlm-Proxy`, `Hlm-Backend`, `Hlm-Selector-Imitator`
- `Ingress` object to access the services
- `values.yaml` which exposes a few of the configuration options

#### Requirements:
- `PostgreSQL` (Helm chart installation)
- `Selenium-Grid` (Helm chart installation) (for [Healenium-Proxy](https://github.com/healenium/healenium))

All configuration variables are presented in `value.yaml` file.

Before you deploy Healenium you should have installed all its dependencies (requirements).
You should have Kubernetes cluster is up and running. Please follow the guides below to run your Kubernetes cluster on different platforms.

> For matching the installation commands on this guide with your command line, please download this Helm chart to your machine.

### Minikube

Minikube is a tool that makes it easy to run Kubernetes locally. Minikube runs a single-node Kubernetes cluster inside a Virtual Machine (VM) on your laptopS

#### Prerequisites

Make sure you have kubectl installed. You can install kubectl according to the instructions in [Install and Set Up kubectl](https://kubernetes.io/docs/tasks/tools/install-kubectl/#install-kubectl-on-linux) guide

#### Run Healenium in Minikube

Start Minikube with the options:
```sh
minikube start
```

Install the Ingress plugin:
```sh
minikube addons enable ingress
```

Initialize Bitname Helm package manager:
```sh
helm repo add bitnami https://charts.bitnami.com/bitnami && helm repo update
```
Clone Healenium Chart repository:
```sh
git clone https://github.com/healenium/kubernetes.git
```

Build Healenium Chart dependency:
```sh
sudo helm dependency build
```

Install PostgreSQL Helm chart
```sh
helm install db bitnami/postgresql  -f ./postgresql/values.yaml
```

Install Selenium-Grid Helm chart:
>You don't need to install Selenium-Grid if you use healenium-web lib. If so skip this step

Full instruction to installing the Selenium-Grid you can find [here](https://github.com/SeleniumHQ/docker-selenium/tree/trunk/charts/selenium-grid)  

Initialize Docker-Selenium Helm package manager:
```sh
helm repo add docker-selenium https://www.selenium.dev/docker-selenium && helm repo update
```

Install Selenium-Grid Helm chart: 
```sh
helm install selenium-grid docker-selenium/selenium-grid
```
> Before you deploy Healenium you should have installed all its requirements. Their versions are described in requirements.yaml
> You should also specify correct PostgreSQL and Selenium-Grid addresses and ports in values.yaml
> You can use default values the following params 'user', 'dbName', 'schema' and 'password' or specify your custom.

```yaml
postgresql:
  installdep:
    enable: false
  endpoint:
    address: <postgresql-release-name>-postgresql.default.svc.cluster.local
    port: 5432
    user: healenium_user
    dbName: healenium
    schema: healenium
    password: YDk2nmNs4s9aCP6K

hlmproxy:
  # IF YOU USE HLM-WEB FOR JAVA TESTS SET ENABLE TO false
  enable: true
  name: hlm-proxy
  repository: healenium/hlm-proxy
  tag: 1.3.2
  port: 8085
  resources:
    requests:
      cpu: 200m
      memory: 1024Mi
    limits:
      cpu: 1000m
      memory: 2048Mi
  environment:
    selenium_server_url: http://selenium-hub.default.svc:4444/
    appium_server_url: http://host.docker.internal:4723/wd/hub
    hlm_log_level: info
  healing:
    healenabled: true
    recoverytries: 1
    scorecap: .6
```

Deploy the Healenium Chart within [Healenium-Proxy](https://github.com/healenium/healenium):
```sh
helm install healenium .
```

Deploy the Healenium Chart within [Healenium-Web](https://github.com/healenium/healenium-web):
```sh
helm install healenium --set hlmproxy.enable=false .
```

If you use Healenium Chart within healenium-web be sure to check `hlm.server.url` and `hlm.imitator.url` in the `healenium.properties` . 

Both should be specified without ports as used ingress-controller
```properties
hlm.server.url = http://localhost
hlm.imitator.url = http://localhost
```

The default URL to reach the ReportPortal UI page is http://healenium.k8s.com.
Make sure that the URL is added to your host file and the IP is the K8s IP address

The command to get an IP address of Minikube:
```sh
minikube ip
```
Example of the host file:
```sh
192.168.99.100 healenium.k8s.com
```


 
