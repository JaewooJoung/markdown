#!/bin/bash

if [ "$EUID" -ne 0 ]; then 
    echo "Please run as root"
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

# Clean the disk completely
echo "Cleaning disk..."
dd if=/dev/zero of=${DEVICE} bs=1M count=100
dd if=/dev/zero of=${DEVICE} bs=1M seek=$(( $(blockdev --getsz ${DEVICE}) / 2048 - 100)) count=100
wipefs -af ${DEVICE}
sgdisk -Z ${DEVICE}

# Create fresh GPT
sgdisk -o ${DEVICE}

# Create partitions with specific partition type GUIDs
sgdisk -n 1:0:+1G -t 1:ef00 -c 1:"EFI System Partition" ${DEVICE}    # Larger EFI partition
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

# Mount partitions
echo "Mounting partitions..."
mount ${ROOT_PART} /mnt
mkdir -p /mnt/boot/efi
mount ${EFI_PART} /mnt/boot/efi
swapon ${SWAP_PART}

# Install essential packages
echo "Installing base system..."
pacstrap -K /mnt base linux linux-firmware \
    base-devel intel-ucode amd-ucode \
    networkmanager vim grub efibootmgr \
    xorg plasma plasma-desktop sddm \
    firefox konsole dolphin \
    sudo dosfstools mtools os-prober

# Generate fstab
echo "Generating fstab..."
genfstab -U /mnt >> /mnt/etc/fstab

# Configure the system
arch-chroot /mnt /bin/bash <<'CHROOT_COMMANDS'
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

# Prepare boot directories
mkdir -p /boot/efi/EFI/BOOT
mkdir -p /boot/efi/EFI/GRUB
mkdir -p /boot/grub

# Configure GRUB for UEFI
cat > /etc/default/grub <<EOF
GRUB_DEFAULT=0
GRUB_TIMEOUT=5
GRUB_DISTRIBUTOR="Arch"
GRUB_CMDLINE_LINUX_DEFAULT="quiet"
GRUB_CMDLINE_LINUX=""
GRUB_PRELOAD_MODULES="part_gpt part_msdos"
GRUB_TIMEOUT_STYLE=menu
GRUB_TERMINAL_INPUT=console
GRUB_GFXMODE=auto
GRUB_GFXPAYLOAD_LINUX=keep
GRUB_DISABLE_OS_PROBER=false
EOF

# Install GRUB for UEFI
grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=GRUB --recheck
grub-install --target=x86_64-efi --efi-directory=/boot/efi --removable --recheck

# Generate GRUB configuration
grub-mkconfig -o /boot/grub/grub.cfg

# Create additional EFI boot entries
mkdir -p /boot/efi/EFI/BOOT
cp /boot/efi/EFI/GRUB/grubx64.efi /boot/efi/EFI/BOOT/BOOTX64.EFI
cp /boot/grub/grub.cfg /boot/efi/EFI/GRUB/
cp /boot/grub/grub.cfg /boot/efi/EFI/BOOT/

# Create UEFI boot entries manually
efibootmgr --create --disk ${DEVICE} --part 1 --loader /EFI/GRUB/grubx64.efi --label "GRUB" --verbose
efibootmgr --create --disk ${DEVICE} --part 1 --loader /EFI/BOOT/BOOTX64.EFI --label "Arch Linux Fallback" --verbose

# Enable services
systemctl enable NetworkManager
systemctl enable sddm

# Generate initial ramdisk
mkinitcpio -P
CHROOT_COMMANDS

umount -R /mnt

echo "Installation complete!"
echo ""
echo "IMPORTANT POST-INSTALLATION STEPS:"
echo "1. Power off the computer completely (not reboot)"
echo "2. Remove the USB drive"
echo "3. Enter BIOS setup and make these EXACT changes:"
echo "   a. Load BIOS defaults first"
echo "   b. Disable Secure Boot"
echo "   c. Set UEFI boot mode (disable CSM/Legacy completely)"
echo "   d. Set Boot Device Priority:"
echo "      - First: nvme0n1"
echo "      - Disable or remove other boot options"
echo "   e. Save changes and exit"
echo ""
echo "Login credentials:"
echo "Username: crux"
echo "Password: 1234"
