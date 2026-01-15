#!/bin/bash
set -e

log() { echo "[INFO] $(date) $1" | tee -a /var/log/sre-cleanup.log; }
log_err() { echo "[ERROR] $(date) $1" | tee -a /var/log/sre-cleanup.log; }

# Get the actual user (not root when using sudo)
if [ -n "$SUDO_USER" ]; then
  FIRST_USER="$SUDO_USER"
else
  FIRST_USER=$(whoami)
fi

log "Starting cleanup process for AMI creation"
log "This script will safely remove authorized_keys without breaking minikube"

# Step 1: Stop all services
log "Step 1: Stopping services"
sudo systemctl stop nginx || true
sudo systemctl stop rule-engine-minikube || true

# Step 2: Stop and DELETE minikube cluster (this frees up containerd resources)
log "Step 2: Stopping and deleting minikube cluster"
if [ -n "$SUDO_USER" ]; then
  sudo -u "$SUDO_USER" minikube stop || true
  sudo -u "$SUDO_USER" minikube delete || true
else
  minikube stop || true
  minikube delete || true
fi

# Wait for minikube cleanup to complete
sleep 5

# Step 3: Clean up all containers and images while services are still running
log "Step 3: Cleaning up containerd and docker resources"
# Clean containerd (k8s.io namespace)
sudo ctr -n k8s.io containers list -q 2>/dev/null | while read container; do
  sudo ctr -n k8s.io containers delete "$container" 2>/dev/null || true
done || true

sudo ctr images list -q 2>/dev/null | while read image; do
  sudo ctr images remove "$image" 2>/dev/null || true
done || true

# Clean docker
sudo docker container prune -f 2>/dev/null || true
sudo docker image prune -af 2>/dev/null || true
sudo docker volume prune -f 2>/dev/null || true
sudo docker system prune -af 2>/dev/null || true

# Wait a bit more
sleep 3

# Step 4: Stop containerd and docker to ensure no active containers
log "Step 4: Stopping containerd and docker"
sudo systemctl stop containerd || true
sudo systemctl stop docker || true

# Wait for services to fully stop
sleep 3

# Step 5: NOW it's safe to remove authorized_keys from overlay filesystems
log "Step 5: Removing authorized_keys files (now safe - no active containers)"
sudo rm -f /home/ubuntu/.ssh/authorized_keys
sudo rm -f /root/.ssh/authorized_keys
sudo find /var/lib/containerd -name "authorized_keys" -delete 2>/dev/null || true
sudo find /var/lib/docker -name "authorized_keys" -delete 2>/dev/null || true

# Step 6: Remove SSH host keys (will be regenerated on first boot)
log "Step 6: Removing SSH host keys"
sudo rm -f /etc/ssh/ssh_host_*

# Step 7: Clear logs and temp files
log "Step 7: Clearing logs and temp files"
sudo rm -rf /tmp/*
sudo rm -rf /var/tmp/*
sudo journalctl --vacuum-time=1d 2>/dev/null || true

# Step 8: Clear bash history
log "Step 8: Clearing bash history"
sudo rm -f /home/ubuntu/.bash_history
sudo rm -f /root/.bash_history
history -c 2>/dev/null || true

# Step 9: Restart containerd and docker (minikube will recreate cluster on next boot)
log "Step 9: Restarting containerd and docker"
sudo systemctl start containerd || true
sudo systemctl start docker || true

# Step 10: Sync filesystem
log "Step 10: Syncing filesystem"
sync

log ""
log "=========================================="
log "Cleanup completed successfully!"
log "=========================================="
log ""
log "IMPORTANT NOTES:"
log "1. Minikube cluster was deleted - it will be recreated automatically on first boot"
log "2. All container images were removed - they will be re-downloaded on first boot"
log "3. authorized_keys have been safely removed from all locations"
log "4. System is now ready for AMI creation"
log "5. After creating AMI, use a NEW EC2 Key Pair to SSH into instances"
log ""
log "Next steps:"
log "- Create AMI from this instance immediately (do not reboot)"
log "- Minikube will start automatically on first boot via systemd service"
log "- Kubernetes cluster will be recreated with all your Helm charts"

