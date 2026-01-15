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
  # Create startup script that will be run by systemd
  sudo tee /usr/local/bin/start-healenium.sh <<'EOF' > /dev/null
#!/bin/bash
set -e

log() { echo "[INFO] $(date) $1" | tee -a /var/log/healenium-startup.log; }

log "Starting Healenium system..."

# Chart directory (copied during init.sh)
CHART_DIR="/opt/healenium/charts"
if [ ! -f "$CHART_DIR/Chart.yaml" ]; then
  log "ERROR: Chart.yaml not found at $CHART_DIR"
  log "Run init.sh first to prepare the AMI"
  exit 1
fi

# Start minikube
log "Starting minikube..."
TOTAL_MEM=$(free -m | awk '/^Mem:/{print $2}')
MINIKUBE_MEM=$(( TOTAL_MEM * 80 / 100 ))
log "Allocating ${MINIKUBE_MEM}MB to minikube"

minikube start --driver=docker --container-runtime=containerd -n 1 --force --interactive=false --memory=${MINIKUBE_MEM}m --cpus=max

# Wait for minikube to be ready
log "Waiting for minikube to be ready..."
kubectl wait --for=condition=Ready nodes --all --timeout=300s || true

# Generate passwords
ADMIN_PASS=$(openssl rand -base64 20)
USER_PASS=$(openssl rand -base64 20)

log "Creating Kubernetes secret with passwords..."
kubectl create secret generic hlm-secret \
  --from-literal=adminPassword=$ADMIN_PASS \
  --from-literal=userPassword=$USER_PASS \
  --dry-run=client -o yaml | kubectl apply -f -

# Check if helm releases already exist
if helm list 2>/dev/null | grep -q healenium; then
  log "Healenium already installed, skipping helm install"
else
  log "Installing Helm charts from $CHART_DIR..."
  
  # Helm repos should already be configured, but update just in case
  helm repo update 2>/dev/null || true
  
  # Install charts
  log "Installing PostgreSQL..."
  helm install db bitnami/postgresql -f "$CHART_DIR/postgresql/values.yaml"
  
  log "Installing Healenium..."
  helm install healenium "$CHART_DIR"
  
  log "Installing Selenium Grid..."
  helm install selenium-grid docker-selenium/selenium-grid
fi

log "Healenium startup complete!"
log "Admin password: $ADMIN_PASS"
log "User password: $USER_PASS"
log "Passwords are stored in Kubernetes secret 'hlm-secret'"

EOF

  sudo chmod +x /usr/local/bin/start-healenium.sh
  
  # Create systemd service
  sudo tee /etc/systemd/system/rule-engine-minikube.service <<EOF > /dev/null
[Unit]
Description=Healenium minikube and services startup
After=docker.service network-online.target
Wants=network-online.target

[Service]
Type=oneshot
ExecStart=/usr/local/bin/start-healenium.sh
ExecStop=/usr/bin/minikube stop
User=$FIRST_USER
Group=$FIRST_USER
RemainAfterExit=yes
TimeoutStartSec=600

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
# Get kubectl version first
KUBECTL_VERSION=$(curl -L -s https://dl.k8s.io/release/stable.txt | tr -d '[:space:]')
if [ -z "$KUBECTL_VERSION" ]; then
  log_err "Failed to get kubectl version. Exiting."
  exit 1
fi
log "Installing kubectl version: $KUBECTL_VERSION"

# Map architecture: dpkg uses 'amd64', Kubernetes uses 'amd64' (same, but ensure consistency)
ARCH=$(dpkg --print-architecture)
if [ -z "$ARCH" ]; then
  log_err "Failed to determine system architecture. Exiting."
  exit 1
fi
# Kubernetes uses 'amd64' for x86_64, keep as is
KUBECTL_ARCH="$ARCH"

KUBECTL_URL="https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/${KUBECTL_ARCH}/kubectl"
SHA256_URL="https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/${KUBECTL_ARCH}/kubectl.sha256"

log "Downloading kubectl from: $KUBECTL_URL"
curl -L -o kubectl "$KUBECTL_URL" || { log_err "Failed to download kubectl. Exiting."; exit 1; }
curl -L -o kubectl.sha256 "$SHA256_URL" || { log_err "Failed to download kubectl.sha256. Exiting."; exit 1; }

echo "$(cat kubectl.sha256)  kubectl" | sha256sum --check || { log_err "kubectl checksum verification failed. Exiting."; exit 1; }
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl && rm kubectl kubectl.sha256


# https://helm.sh/docs/intro/install/
log "Installing helm via official script (more reliable than apt)"
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash


# Copy charts to standard location for AMI
log "Copying Helm charts to /opt/healenium/"
sudo mkdir -p /opt/healenium
sudo cp -r "$SCRIPT_DIR" /opt/healenium/charts
sudo chown -R "$FIRST_USER:$FIRST_USER" /opt/healenium

# Prepare Helm repos (as FIRST_USER)
log "Configuring Helm repositories"
sudo -u "$FIRST_USER" bash <<'EOF'
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo add docker-selenium https://www.selenium.dev/docker-selenium
helm repo update
cd /opt/healenium/charts
helm dependency build
EOF

log "Helm charts prepared in /opt/healenium/charts/"
log "NOTE: Minikube and services will start automatically on first boot via systemd"

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

        # API routes → hlm-proxy (routes to backend/AI internally)
        location ~ ^/(healenium|screenshots|healenium-ai|hlm-proxy) {
            proxy_pass http://192.168.49.2:30085;
            proxy_set_header Host $http_host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
        }

        location /wd/hub {
            proxy_pass http://192.168.49.2:30085;
            proxy_set_header Host $http_host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
        }

        location / {
            proxy_pass http://192.168.49.2:30173;
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

log "=========================================="
log "Healenium AMI preparation complete!"
log "=========================================="
log ""
log "Installed components:"
log "  ✓ Docker"
log "  ✓ Minikube"
log "  ✓ Kubectl"
log "  ✓ Helm"
log "  ✓ Nginx"
log "  ✓ Helm charts copied to /opt/healenium/charts/"
log "  ✓ Systemd service configured (will start on boot)"
log ""
log "=========================================="
log "NEXT STEPS FOR AMI CREATION:"
log "=========================================="
log "1. (Optional) Test: sudo systemctl start rule-engine-minikube.service"
log "2. Run: sudo bash $(dirname "$0")/prepare-ami.sh"
log "3. Create AMI: aws ec2 create-image --instance-id i-xxx --name healenium --no-reboot"
log "4. Terminate this instance after AMI creation"
log ""
log "When new instances launch from the AMI:"
log "  - Minikube will start automatically (2-3 minutes)"
log "  - All services will be deployed automatically"
log "  - UI will be available at http://INSTANCE_IP"
log ""