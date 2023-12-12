#!/usr/bin/env bash

# This script automates the creation and registration of a Github self-hosted runner within a Proxmox LXC (Linux Container).
# The runner is based on Ubuntu 23.04. Before running the script, ensure you have your GITHUB_TOKEN 
# and the OWNERREPO (github owner/repository) available.

set -e

# Variables
GITHUB_RUNNER_URL="https://github.com/actions/runner/releases/download/v2.311.0/actions-runner-linux-x64-2.311.0.tar.gz"
TEMPL_URL="http://download.proxmox.com/images/system/ubuntu-23.04-standard_23.04-1_amd64.tar.zst"
PCTSIZE="20G"
PCT_ARCH="amd64"
PCT_CORES="4"
PCT_MEMORY="4096"
PCT_SWAP="4096"
PCT_STORAGE="local-lvm"

# Ask for GitHub token and owner/repo if they're not set
if [ -z "$GITHUB_TOKEN" ]; then
    read -r -p "Enter github token: " GITHUB_TOKEN
    echo
fi
if [ -z "$OWNERREPO" ]; then
    read -r -p "Enter github owner/repo: " OWNERREPO
    echo
fi

# log function prints text in yellow
log() {
  local text="$1"
  echo -e "\033[33m$text\033[0m"
}

# Prompt for network details
read -r -e -p "Container Address IP (CIDR format): " -i "192.168.0.123/24" IP_ADDR
read -r -e -p "Container Gateway IP: " -i "192.168.0.1" GATEWAY

# Get filename from the URLs
TEMPL_FILE=$(basename $TEMPL_URL)
GITHUB_RUNNER_FILE=$(basename $GITHUB_RUNNER_URL)

# Get the next available ID from Proxmox
PCTID=$(pvesh get /cluster/nextid)

# Download Ubuntu template
log "-- Downloading $TEMPL_FILE template..."
curl -q -C - -o "$TEMPL_FILE" $TEMPL_URL

# Create LXC container
log "-- Creating LXC container with ID:$PCTID"
pct create "$PCTID" "$TEMPL_FILE" \
   -arch $PCT_ARCH \
   -ostype ubuntu \
   -hostname github-runner-proxmox-$(openssl rand -hex 3) \
   -cores $PCT_CORES \
   -memory $PCT_MEMORY \
   -swap $PCT_SWAP \
   -storage $PCT_STORAGE \
   -features nesting=1,keyctl=1 \
   -net0 name=eth0,bridge=vmbr0,gw="$GATEWAY",ip="$IP_ADDR",type=veth

# Resize the container
log "-- Resizing container to $PCTSIZE"
pct resize "$PCTID" rootfs $PCTSIZE

# Start the container & run updates inside it
log "-- Starting container"
pct start "$PCTID"
sleep 10
log "-- Running updates"
pct exec "$PCTID" -- bash -c "apt update -y && apt install -y git curl zip && passwd -d root"

# Install Docker inside the container
log "-- Installing docker"
pct exec "$PCTID" -- bash -c "curl -qfsSL https://get.docker.com | sh"

# Get runner installation token
log "-- Getting runner installation token"
RES=$(curl -q -L \
  -X POST \
  -H "Accept: application/vnd.github+json" \
  -H "Authorization: Bearer $GITHUB_TOKEN"  \
  -H "X-GitHub-Api-Version: 2022-11-28" \
  https://api.github.com/repos/$OWNERREPO/actions/runners/registration-token)

RUNNER_TOKEN=$(echo $RES | grep -o '"token": "[^"]*' | grep -o '[^"]*$')

# Install and start the runner
log "-- Installing runner"
pct exec "$PCTID" -- bash -c "mkdir actions-runner && cd actions-runner &&\
    curl -o $GITHUB_RUNNER_FILE -L $GITHUB_RUNNER_URL &&\
    tar xzf $GITHUB_RUNNER_FILE &&\
    RUNNER_ALLOW_RUNASROOT=1 ./config.sh --unattended --url https://github.com/$OWNERREPO --token $RUNNER_TOKEN &&\
    ./svc.sh install root &&\
    ./svc.sh start"

# Delete the downloaded Ubuntu template
rm "$TEMPL_FILE"
