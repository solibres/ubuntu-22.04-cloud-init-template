#!/bin/bash

##############################################################################
# things to double-check:
# 1. user directory
# 2. your SSH key location
# 3. which bridge you assign with the create line (currently set to vmbr1)
# 4. which storage is being utilized (script uses local)
##############################################################################
figlet Ubuntu 22.04 cloud-init
echo "Please, wait..."
### Cloudinit Image erstellen (Ubuntu 22.04)
DISK_IMAGE="jammy-server-cloudimg-amd64.img"
IMAGE_URL="https://cloud-images.ubuntu.com/jammy/current/$DISK_IMAGE"

cd /var/lib/vz/template/iso/

# Function to check if a file was modified in the last 24 hours or doesn't exist
should_download_image() {
    local file="$1"
    # If file doesn't exist, return true (i.e., should download)
    [[ ! -f "$file" ]] && return 0

    local current_time=$(date +%s)
    local file_mod_time=$(stat --format="%Y" "$file")
    local difference=$(( current_time - file_mod_time ))
    # If older than 24 hours, return true
    (( difference >= 86400 ))
}

# Download the disk image if it doesn't exist or if it was modified more than 24 hours ago
if should_download_image "$DISK_IMAGE"; then
    rm -f "$DISK_IMAGE"
    wget -q "$IMAGE_URL"
fi

sudo virt-customize -a /var/lib/vz/template/iso/$DISK_IMAGE --install qemu-guest-agent &&
sudo apt update -y && sudo apt install libguestfs-tools net-tools htop neofetch -y &&
sudo virt-customize -a /var/lib/vz/template/iso/$DISK_IMAGE --root-password password:Str0ngP4ssworD &&
sudo virt-customize -a /var/lib/vz/template/iso/$DISK_IMAGE --run-command "echo -n > /etc/machine-id"

### Cloudinit Template VM erstellen (Ubuntu 22.04)

qm create 999 --name "ubuntu-2204-cloudinit-template" --memory 4095 --sockets 2 --cores 2 --net0 virtio,bridge=vmbr1 --bios ovmf --machine q35 
qm importdisk 999 /var/lib/vz/template/iso/$DISK_IMAGE local 
qm set 999 --scsihw virtio-scsi-single --scsi0 local:999/vm-999-disk-0.raw,size=40G,cache=writeback,discard=on,ssd=1 
qm set 999 --scsi1 local:50,cache=writeback,discard=on,ssd=1 
qm set 999 --boot c --bootdisk scsi0 
qm set 999 --ide2 local:cloudinit,format=raw
qm set 999 --agent enabled=1 
# qm resize 999 scsi0 +27748M 
qm set 999 --serial0 socket 
qm set 999 --vga serial0 
qm set 999 --cpu cputype=host 
qm set 999 --ostype l26 
qm set 999 --balloon 2048 
# qm set 999 --ciupgrade 1 
# qm set 999 --ciuser ansible 
qm set 999 --cicustom "user=local:snippets/999.yaml" # absolute path = /var/lib/vz/snippets
qm set 999 --ipconfig0 ip=dhcp 
qm set 999 --nameserver 8.8.8.8 
qm set 999 --sshkeys /root/.ssh/authorized_keys
qm template 999

echo "Next up, clone VM, then expand the disk"
echo "You also still need to copy ssh keys to the newly cloned VM"

figlet Felicitations !

echo "Template créé avec succès !"
