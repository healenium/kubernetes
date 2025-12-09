#!/bin/bash
set -e

# Get the actual user (not root when using sudo)
if [ -n "$SUDO_USER" ]; then
  export FIRST_USER="$SUDO_USER"
else
  export FIRST_USER=$(whoami)
fi

# Get chart directory - user must run from kubernetes repo root or pass as argument
if [ -n "$1" ]; then
  SCRIPT_DIR="$1"
elif [ -f "./Chart.yaml" ]; then
  SCRIPT_DIR="$(pwd)"
elif [ -f "../Chart.yaml" ]; then
  SCRIPT_DIR="$(cd .. && pwd)"
else
  echo "ERROR: Chart.yaml not found!"
  echo "Usage: cd /path/to/kubernetes && sudo bash startup/init.sh"
  echo "   or: sudo bash /path/to/kubernetes/startup/init.sh /path/to/kubernetes"
  exit 1
fi
echo "Using chart directory: $SCRIPT_DIR"

log() { echo "[INFO] $(date) $1" | tee -a /var/log/sre-init.log; }
log_err() { echo "[ERROR] $(date) $1" | tee -a /var/log/sre-init.log; }

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
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --batch --yes --dearmor -o /etc/apt/trusted.gpg.d/docker.gpg
sudo chmod a+r /etc/apt/trusted.gpg.d/docker.gpg

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
log "Installing helm via official script (more reliable than apt)"
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash


log "Starting minikube on behalf of $FIRST_USER"
ADMIN_PASS=$(generate_password)
USER_PASS=$(generate_password)

sudo -u "$FIRST_USER" bash <<EOF
echo "Starting minikube..."
# Start with 80% of available memory to leave room for system overhead
TOTAL_MEM=\$(free -m | awk '/^Mem:/{print \$2}')
MINIKUBE_MEM=\$(( TOTAL_MEM * 80 / 100 ))
echo "Allocating \${MINIKUBE_MEM}MB to minikube (80% of \${TOTAL_MEM}MB total)"
minikube start --driver=docker --container-runtime=containerd -n 1 --force --interactive=false --memory=\${MINIKUBE_MEM}m --cpus=max
# Create secret (ignore if exists)
kubectl create secret generic hlm-secret \
  --from-literal=adminPassword=$ADMIN_PASS \
  --from-literal=userPassword=$USER_PASS \
  --dry-run=client -o yaml | kubectl apply -f -
EOF

# Initialize Bitnami Helm package manager (run as FIRST_USER who has kubeconfig)
log "Installing Helm charts from $SCRIPT_DIR"
cd "$SCRIPT_DIR"
sudo -u "$FIRST_USER" helm repo add bitnami https://charts.bitnami.com/bitnami
sudo -u "$FIRST_USER" helm repo add docker-selenium https://www.selenium.dev/docker-selenium
sudo -u "$FIRST_USER" helm repo update
sudo -u "$FIRST_USER" helm dependency build "$SCRIPT_DIR"
sudo -u "$FIRST_USER" helm install db bitnami/postgresql -f "$SCRIPT_DIR/postgresql/values.yaml"
sudo -u "$FIRST_USER" helm install healenium "$SCRIPT_DIR"
sudo -u "$FIRST_USER" helm install selenium-grid docker-selenium/selenium-grid

log "Enabling minikube service"
enable_minikube_service

log "Installing NGINX"
sudo apt-get update && sudo apt-get install nginx -y
echo "NGINX is installed."

sudo mkdir -p /etc/nginx/ssl
sudo chmod 700 /etc/nginx/ssl

sudo openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout /etc/nginx/ssl/selfsigned.key -out /etc/nginx/ssl/selfsigned.crt -subj "/C=US/ST=State/L=City/O=Organization/OU=OrgUnit/CN=example.com"

# Create sites-available and sites-enabled if they don't exist (minimal Ubuntu)
sudo mkdir -p /etc/nginx/sites-available
sudo mkdir -p /etc/nginx/sites-enabled

CONFIG_FILE="/etc/nginx/sites-available/default"

sudo tee "$CONFIG_FILE" > /dev/null <<'EOF'
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

# Enable site
sudo ln -sf /etc/nginx/sites-available/default /etc/nginx/sites-enabled/default

sudo nginx -t || { log_err "NGINX configuration error. Exiting."; exit 1; }

sudo systemctl reload nginx
log "NGINX has been reloaded with the new configuration."

log "Cleaning apt cache"
sudo apt clean
log 'Done. Healenium installation complete!'