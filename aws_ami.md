# Creating AWS AMI for Healenium with Minikube

This guide explains how to create a reusable AWS AMI (Amazon Machine Image) with Healenium and Minikube pre-installed.

## Overview

The AMI creation process:
1. Launch EC2 instance
2. Run setup script (Selenium or Playwright)
3. Create AMI from configured instance
4. Launch new instances from AMI

---

## Prerequisites

- AWS Account with EC2 access
- SSH key pair (or use EC2 Instance Connect)

---

## Step 1: Launch EC2 Instance
0. go to N. Virginia us-east-1
1. **EC2 Console** → **Launch Instance**
2. Configure:
   - **Name**: `healenium-ami-builder`
   - **AMI**: Ubuntu Server _latest_ LTS
   - **Instance Type**: `c5.2xlarge` or larger (Minikube needs 4+ vCPU, 16+ GB RAM)
   - **Key Pair**: Select/create SSH key pair
   - **Storage**: 50 GB minimum
3. Advanced details:
   - **IAM instance profile**: EC2Role   
4. Click **Launch Instance**

---

## Step 2: Connect to Instance

Via Browser or SSH

---

## Step 3: Choose Setup Type

### Option A: Selenium Setup

For Selenium based test automation:

```bash
cd /opt
sudo git clone -b aws_oc https://github.com/healenium/kubernetes.git
sudo chown -R ubuntu:ubuntu /opt/kubernetes
cd /opt/kubernetes
sudo bash startup/init.sh /opt/kubernetes
```

**What it installs:**
- Docker, Minikube, kubectl, Helm, NGINX
- PostgreSQL database
- Selenium Grid
- Healenium with Selenium proxy (`values.yaml`)

---

### Option B: Playwright Setup

For Playwright browser automation:

```bash
cd /opt
sudo git clone -b aws_oc_pw https://github.com/healenium/kubernetes.git
sudo chown -R ubuntu:ubuntu /opt/kubernetes
cd /opt/kubernetes
sudo bash startup/init_pw.sh /opt/kubernetes
```

**What it installs:**
- Docker, Minikube, kubectl, Helm, NGINX
- PostgreSQL database
- Healenium with Playwright proxy and server (`values-playwright.yaml`)
- **No Selenium Grid** (Playwright manages browsers directly)

---

## Step 4: Verify Installation

```bash
# Check Minikube status
newgrp docker
minikube status

# Check Kubernetes pods
kubectl get pods

# Check NGINX
sudo systemctl status nginx

# View logs
sudo tail -f /var/log/sre-init.log
```

**Expected**: Minikube running, pods in "Running" state, NGINX active.

---

## Step 5: Clean Up Before AMI Creation

```bash
# Stop Minikube (don't include running state)
newgrp docker
minikube stop

# Clean temporary files
sudo apt clean
sudo rm -rf /tmp/* /var/tmp/*
history -c
```

---

## Step 6: Create AMI

1. **EC2 Console** → Select instance
2. **Actions** → **Image and templates** → **Create image**
3. Configure:
   - **Image name**: `ami-healenium-pro-selenuim-vX.X` or `ami-healenium-pro-playwright-vX.X`
   - **Description**: `Healenium with Minikube - Selenium/Playwright setup`
4. Click **Create image**
5. Wait 5-15 minutes for status: **"available"**

---

## Step 7: Launch from AMI

1. Select AMI → **Launch instance from AMI**
2. Configure:
   - **Instance Type**: `c5.2xlarge` or larger
   - **Security Groups**: Allow ports 22, 80, 443, 30085, 30173
3. **Launch Instance**

---

## Step 8: Start Services on New Instance

```bash
# SSH into instance
ssh -i your-key.pem ubuntu@<instance-ip>

# Start Minikube
newgrp docker
minikube start
# OR
sudo systemctl start rule-engine-minikube.service

# Verify
minikube status
kubectl get pods 
```

---

## Selenium vs Playwright Comparison

| Feature | Selenium Setup | Playwright Setup |
|---------|---------------|------------------|
| **Script** | `init.sh` | `init_pw.sh` |
| **Branch** | `aws_oc` | `EPMHLM-466--playwright-setup-2` |
| **Values File** | `values.yaml` | `values-playwright.yaml` |
| **Selenium Grid** | ✅ Installed | ❌ Not installed |
| **Selenium Proxy** | ✅ Enabled | ✅ Enabled (API gateway) |
| **Playwright Proxy** | ❌ Not included | ✅ Enabled |
| **Playwright Server** | ❌ Not included | ✅ Enabled |
| **Use Case** | Selenium WebDriver tests | Playwright browser automation |

---

## Important Notes

### Instance Requirements
- **Minimum**: `c5.2xlarge` (4 vCPU, 16 GB RAM)
- **Recommended**: `???` for production

### Security Groups
Open ports:
- **22**: SSH
- **80**: HTTP (NGINX)
- **443**: HTTPS (NGINX)
- **30085**: Minikube NodePort (hlm-proxy)
- **30095**: Minikube NodePort (hlm-playwright-proxy - WebSocket)
- **30173**: Minikube NodePort (hlm-ui-dashboard)

### Network Configuration
- Selenium branch `aws_oc`
- Playwright branch `aws_oc_pw`


