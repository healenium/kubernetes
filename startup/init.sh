#!/bin/bash
{
export FIRST_USER=$(whoami)

log() { echo "[INFO] $(date) $1" >> /var/log/sre-init.log; }
log_err() { echo "[ERROR] $(date) $1" >> /var/log/sre-init.log; }

generate_password() {
  chars="20"
  typ='-base64'
  if [ -n "$1" ]; then
    chars="$1"
  fi
  if [ -n "$2" ]; then
    typ="$2"
  fi
  openssl rand "$typ" "$chars"
}

enable_minikube_service() {
  sudo tee /etc/systemd/system/rule-engine-minikube.service <<EOF > /dev/null
[Unit]
Description=Rule engine minikube start up
After=docker.service

[Service]
Type=oneshot
ExecStart=/usr/bin/minikube start --force --interactive=false
ExecStop=/usr/bin/minikube stop
User=$FIRST_USER
Group=$FIRST_USER
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF
  sudo systemctl enable rule-engine-minikube.service
}


log "The first run. Configuring sre for user $FIRST_USER"

# Prerequisite
log "Installing docker and other necessary packages"
sudo DEBIAN_FRONTEND=noninteractive apt update -y
sudo DEBIAN_FRONTEND=noninteractive apt install -y git jq python3-pip unzip locales-all


# Add Docker's official GPG key: from https://docs.docker.com/engine/install/debian/
sudo DEBIAN_FRONTEND=noninteractive apt install -y ca-certificates curl software-properties-common
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/trusted.gpg.d/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.asc

# Add git apt repo
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/trusted.gpg.d/docker.gpg] https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo DEBIAN_FRONTEND=noninteractive apt update -y
sudo DEBIAN_FRONTEND=noninteractive apt install -y docker-ce docker-ce-cli containerd.io

if [ $(getent group docker) ]; then
   echo "Group 'docker' already exists"
else
   sudo groupadd docker
fi
sudo usermod -aG docker $FIRST_USER

# https://minikube.sigs.k8s.io/docs/start
log "Installing minikube"
curl -LO https://storage.googleapis.com/minikube/releases/latest/minikube_latest_$(dpkg --print-architecture).deb
sudo dpkg -i minikube_latest_$(dpkg --print-architecture).deb && rm minikube_latest_$(dpkg --print-architecture).deb

# https://kubernetes.io/docs/tasks/tools/install-kubectl-linux/#install-kubectl-binary-with-curl-on-linux
log "Installing kubectl"
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/$(dpkg --print-architecture)/kubectl"  # todo specify concrete release
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/$(dpkg --print-architecture)/kubectl.sha256"
echo "$(cat kubectl.sha256)  kubectl" | sha256sum --check || exit 1
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl && rm kubectl kubectl.sha256


# https://helm.sh/docs/intro/install/
log "Installing helm"
curl https://baltocdn.com/helm/signing.asc | gpg --dearmor | sudo tee /usr/share/keyrings/helm.gpg > /dev/null
sudo apt-get install apt-transport-https --yes
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/helm.gpg] https://baltocdn.com/helm/stable/debian/ all main" | \
  sudo tee /etc/apt/sources.list.d/helm-stable-debian.list
sudo apt-get update
sudo apt-get install helm


log "Starting minikube and installing helm releases on behalf of $FIRST_USER"
sudo su - "$FIRST_USER" <<EOF
echo "Start minikube:"
minikube start --driver=docker --container-runtime=containerd -n 1 --force --interactive=false --memory=max --cpus=max
kubectl create secret generic hlm-secret --from-literal=adminPassword=$(generate_password) --from-literal=userPassword=$(generate_password)
EOF

# Initialize Bitname Helm package manager
sudo helm repo add bitnami https://charts.bitnami.com/bitnami && helm repo update
sudo helm dependency build
sudo helm install db bitnami/postgresql -f ./postgresql/values.yaml
sudo helm install healenium .

sudo helm repo add docker-selenium https://www.selenium.dev/docker-selenium && helm repo update
sudo helm install selenium-grid docker-selenium/selenium-grid

log "Enabling minikube service"
enable_minikube_service

set -e

sudo apt-get update && sudo apt-get install nginx -y
echo "NGINX is installed."

sudo mkdir -p /etc/nginx/ssl
sudo chmod 700 /etc/nginx/ssl

sudo openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout /etc/nginx/ssl/selfsigned.key -out /etc/nginx/ssl/selfsigned.crt -subj "/C=US/ST=State/L=City/O=Organization/OU=OrgUnit/CN=example.com"

CONFIG_FILE="/etc/nginx/sites-available/default"

sudo bash -c "cat > $CONFIG_FILE" <<'EOF'
server {

server_name localhost;
        listen 80 default_server;
        listen [::]:80 default_server;

        listen 443 ssl default_server;
        listen [::]:443 ssl default_server;

        ssl_certificate /etc/nginx/ssl/selfsigned.crt;
        ssl_certificate_key /etc/nginx/ssl/selfsigned.key;

         location /healenium {
                proxy_pass http://192.168.49.2:30078;
                proxy_set_header Host $http_host;
                proxy_set_header X-Real-IP $remote_addr;
                proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
                proxy_set_header X-Forwarded-Proto $scheme;
        }

        location /screenshots {
                proxy_pass http://192.168.49.2:30078;
                proxy_set_header Host $http_host;
                proxy_set_header X-Real-IP $remote_addr;
                proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
                proxy_set_header X-Forwarded-Proto $scheme;
        }

        location /wd/hub {
            proxy_pass http://192.168.49.2:30044;
            proxy_set_header Host $http_host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
        }

        location / {
            proxy_pass http://192.168.49.2:30085;
            proxy_set_header Host $http_host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
        }
}
EOF

sudo nginx -t || (echo "NGINX configuration error. Exiting."; exit 1)

sudo systemctl reload nginx
echo "NGINX has been reloaded with the new configuration."

log "Cleaning apt cache"
sudo apt clean
log 'Done'
} &> /var/log/healenium_startup.log