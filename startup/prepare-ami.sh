#!/bin/bash
# Script to prepare EC2 instance for AMI creation
# Run this AFTER init.sh and AFTER you've verified everything works
# Usage: sudo bash prepare-ami.sh

set -e

log() { echo "[INFO] $(date) $1"; }
log_err() { echo "[ERROR] $(date) $1"; }

log "=========================================="
log "Preparing instance for AMI creation"
log "=========================================="

# Get the actual user (not root when using sudo)
if [ -n "$SUDO_USER" ]; then
  FIRST_USER="$SUDO_USER"
else
  FIRST_USER=$(whoami)
fi

log "Stopping minikube gracefully"
sudo -u "$FIRST_USER" minikube stop || log_err "Failed to stop minikube (may not be running)"

log "Waiting for minikube to fully stop..."
sleep 10

# Remove authorized_keys from standard locations
log "Removing authorized keys from home directories"
sudo rm -f /home/ubuntu/.ssh/authorized_keys
sudo rm -f /root/.ssh/authorized_keys
sudo rm -f /home/*/.ssh/authorized_keys

# Remove authorized_keys from containerd snapshots (created by minikube/docker)
log "Removing authorized keys from containerd snapshots"
sudo find /var/lib/containerd -name "authorized_keys" -delete 2>/dev/null || true

# Remove SSH host keys (will be regenerated on first boot)
log "Removing SSH host keys (will be regenerated on first boot)"
sudo rm -f /etc/ssh/ssh_host_*

# Clear logs and temp files
log "Clearing temporary files and logs"
sudo rm -rf /tmp/*
sudo rm -rf /var/tmp/*
sudo journalctl --vacuum-time=1s 2>/dev/null || true

# Clear bash history
log "Clearing bash history"
sudo rm -f /home/ubuntu/.bash_history
sudo rm -f /root/.bash_history
sudo rm -f /home/*/.bash_history
history -c 2>/dev/null || true

# Clear cloud-init logs (optional)
log "Clearing cloud-init logs"
sudo rm -rf /var/log/cloud-init*.log 2>/dev/null || true

# Clear system logs
log "Clearing system logs"
sudo find /var/log -type f -name "*.log" -exec truncate -s 0 {} \; 2>/dev/null || true

# Clear apt cache
log "Cleaning apt cache"
sudo apt clean

# Remove machine-id (will be regenerated)
log "Clearing machine ID"
sudo truncate -s 0 /etc/machine-id
sudo rm -f /var/lib/dbus/machine-id
sudo ln -sf /etc/machine-id /var/lib/dbus/machine-id

# Disable cloud-init to prevent it from running on first boot
# (Optional - uncomment if you don't want cloud-init to run)
# sudo touch /etc/cloud/cloud-init.disabled

log "=========================================="
log "AMI preparation complete!"
log "=========================================="
log ""
log "NEXT STEPS:"
log "1. Create AMI from this instance: aws ec2 create-image ..."
log "2. When launching new instances from this AMI:"
log "   - SSH host keys will be auto-generated on first boot"
log "   - You'll need to provide a new EC2 Key Pair"
log "   - Minikube will start automatically via systemd service"
log ""
log "IMPORTANT:"
log "- DO NOT SSH into this instance after running this script"
log "- Create the AMI immediately"
log "- Terminate this instance after AMI creation"
log ""

