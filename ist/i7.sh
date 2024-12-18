#!/bin/bash

if [ "$EUID" -ne 0 ]; then 
    echo "Please run as root"
    exit 1
fi

# Verify we're in UEFI mode
if [ ! -d "/sys/firmware/efi/efivars" ]; then
    echo "Not booted in UEFI mode. Please enable UEFI in your BIOS settings."
    exit 1
fi

# Disk setup
DEVICE="/dev/nvme0n1"
EFI_PART="${DEVICE}p1"
SWAP_PART="${DEVICE}p2"
ROOT_PART="${DEVICE}p3"

echo "WARNING: This will COMPLETELY ERASE all data on ${DEVICE}. Are you sure? (y/N)"
read confirm
if [ "$confirm" != "y" ]; then
    echo "Aborted"
    exit 1
fi

# Ensure system clock is accurate
timedatectl set-ntp true

# Clean the disk
echo "Cleaning disk..."
wipefs -af ${DEVICE}
sgdisk -Z ${DEVICE}

# Create new GPT
sgdisk -o ${DEVICE}

# Create partitions following official recommendations
sgdisk -n 1:0:+512M -t 1:ef00 -c 1:"EFI System Partition" ${DEVICE}  # EFI partition
sgdisk -n 2:0:+8G -t 2:8200 -c 2:"Linux swap" ${DEVICE}             # Swap partition
sgdisk -n 3:0:0 -t 3:8300 -c 3:"Linux root" ${DEVICE}               # Root partition

# Wait for kernel to update partition table
sleep 3
partprobe ${DEVICE}
sleep 3

# Format partitions
echo "Formatting partitions..."
mkfs.fat -F 32 ${EFI_PART}
mkswap ${SWAP_PART}
mkfs.ext4 ${ROOT_PART}

# Mount partitions in correct order
echo "Mounting partitions..."
mount ${ROOT_PART} /mnt
mount --mkdir ${EFI_PART} /mnt/boot
swapon ${SWAP_PART}

# Install essential packages
echo "Installing base system..."
pacstrap -K /mnt base linux linux-firmware \
    base-devel intel-ucode amd-ucode \
    networkmanager vim grub efibootmgr \
    xorg plasma plasma-desktop sddm \
    firefox konsole dolphin \
    sudo

# Generate fstab
echo "Generating fstab..."
genfstab -U /mnt >> /mnt/etc/fstab

# Configure the system
arch-chroot /mnt /bin/bash <<CHROOT_COMMANDS
# Set timezone
ln -sf /usr/share/zoneinfo/Europe/Stockholm /etc/localtime
hwclock --systohc

# Set locale
echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen
echo "ko_KR.UTF-8 UTF-8" >> /etc/locale.gen
locale-gen
echo "LANG=en_US.UTF-8" > /etc/locale.conf

# Set hostname
echo "lia" > /etc/hostname
cat > /etc/hosts <<EOF
127.0.0.1   localhost
::1         localhost
127.0.1.1   lia.localdomain lia
EOF

# Set root password
echo "root:1234" | chpasswd

# Create user
useradd -m -G wheel -s /bin/bash crux
echo "crux:1234" | chpasswd
echo "%wheel ALL=(ALL:ALL) NOPASSWD: ALL" > /etc/sudoers.d/wheel

# Install and configure bootloader
grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB --recheck
grub-install --target=x86_64-efi --efi-directory=/boot --removable --recheck

# Create GRUB configuration
sed -i 's/#GRUB_DISABLE_OS_PROBER=false/GRUB_DISABLE_OS_PROBER=false/' /etc/default/grub
grub-mkconfig -o /boot/grub/grub.cfg

# Enable necessary services
systemctl enable NetworkManager
systemctl enable sddm

# Create EFI fallback
mkdir -p /boot/EFI/BOOT
cp /boot/EFI/GRUB/grubx64.efi /boot/EFI/BOOT/BOOTX64.EFI

# Generate initial ramdisk
mkinitcpio -P
CHROOT_COMMANDS

# Final steps
umount -R /mnt

echo "Installation complete!"
echo "Please remove the installation media and reboot."
echo "Login credentials:"
echo "Username: crux"
echo "Password: 1234"
