# proxmox_scripts

Set of Proxmox scripts that can be useful for anyone.

Tested on Proxmox VE 8.

## Run a command in all nodes

Write the following script into a file name `cssh`:
```bash
#!/bin/bash
if [ ! -n "$1" ]; then echo "Usage: $0 [command]"; else
for n in $(cat /etc/pve/.members  | jq -r '.nodelist[].ip'); do
echo --- $n -----------------------------------------------------
ssh -T $n "$@"
done
fi
```

Example output:
```bash
root@proxmox-1:~# chmod ./cssh
root@proxmox-1:~# ./cssh cat /etc/debian_version
--- 192.168.1.10 -----------------------------------------------------
12.2
--- 192.168.1.10 -----------------------------------------------------
12.2
--- 192.168.1.11 -----------------------------------------------------
12.2
--- 192.168.1.12 -----------------------------------------------------
12.2
--- 192.168.1.13 -----------------------------------------------------
12.2
```

## [lxc_create_github_actions_runner.sh](./lxc_create_github_actions_runner.sh)

Creates and sets up a self-hosted GitHub Actions runner in an LXC container on Proxmox:

1. Create a new LXC container based on ubuntu 23.04
1. Installs apt-get dependencies (git, curl)
1. Installs docker
1. Installs Github actions (needs GITHUB_TOKEN and OWNERREPO) and sets up service

NOTE: Since the new container has docker support, it cannot be run unpriviledged. This approach is more insecure than using a full-blown VM, at the benefit of being much faster most times. That being said, make sure you only use this self-hosted runner in contexts that you can control at all times (e.g. careful using with public repositories).

### Instructions

```bash
# Download the script
curl -O https://raw.githubusercontent.com/oNaiPs/proxmox-scripts/main/lxc_create_github_actions_runner.sh

# Inspect script, customize variables

# Run the script
bash lxc_create_github_actions_runner.sh
```

Warning: make sure you read and understand the code you are running before executing it on your machine.
