#!/bin/bash

# Check root privileges
if [ "$EUID" -ne 0 ]; then 
    echo "Please run as root"
    exit 1
fi

# Specify installation device
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

# Unmount existing partitions and disable swap
echo "Unmounting all partitions and disabling swap..."
swapoff -a
umount -R /mnt 2>/dev/null
umount -R ${DEVICE}* 2>/dev/null

# Complete disk cleanup
echo "Thoroughly cleaning the disk..."
# Delete all partition tables and signatures
dd if=/dev/zero of=${DEVICE} bs=512 count=2048
dd if=/dev/zero of=${DEVICE} bs=512 count=2048 seek=$(( $(blockdev --getsz ${DEVICE}) - 2048 ))

# Clear any remaining signatures
wipefs -a ${DEVICE}

# Force kernel to reread partition table
echo "Forcing kernel to re-read partition table..."
partprobe ${DEVICE}
sleep 2

# Create partitions
echo "Creating partitions..."
(
echo g    # Create new GPT partition table
echo n    # New partition
echo 1    # Partition number
echo      # Default first sector
echo +1G  # 1GB for EFI
echo n    # New partition
echo 2    # Partition number
echo      # Default first sector
echo +8G  # 8GB for swap
echo n    # New partition
echo 3    # Partition number
echo      # Default first sector
echo      # Use remaining space
echo t    # Change partition type
echo 1    # Select first partition
echo 1    # EFI System
echo t    # Change partition type
echo 2    # Select second partition
echo 19   # Linux swap
echo w    # Write changes
) | fdisk ${DEVICE}

# Wait for kernel to update partition table
echo "Waiting for partition table update..."
partprobe ${DEVICE}
sleep 5

# Format partitions
echo "Formatting partitions..."
mkfs.fat -F32 ${EFI_PART}
mkswap ${SWAP_PART}
mkfs.ext4 ${ROOT_PART}

# Mount partitions
echo "Mounting partitions..."
mount ${ROOT_PART} /mnt
mkdir -p /mnt/boot
mount ${EFI_PART} /mnt/boot
swapon ${SWAP_PART}

# Install base system
echo "Installing base system..."
pacstrap /mnt base linux linux-firmware base-devel networkmanager vim sudo

# Install X.org and KDE
echo "Installing KDE Plasma..."
pacstrap /mnt xorg plasma plasma-desktop sddm \
    firefox konsole dolphin kate \
    pulseaudio pulseaudio-alsa alsa-utils \
    cups cups-pdf \
    git wget

# Generate fstab
echo "Generating fstab..."
genfstab -U /mnt >> /mnt/etc/fstab

# Create chroot setup script
cat > /mnt/setup.sh <<'EOF'
#!/bin/bash

# Set timezone
ln -sf /usr/share/zoneinfo/Europe/Stockholm /etc/localtime
hwclock --systohc

# Set locale
sed -i 's/#en_US.UTF-8/en_US.UTF-8/' /etc/locale.gen
sed -i 's/#ko_KR.UTF-8/ko_KR.UTF-8/' /etc/locale.gen
locale-gen
echo "LANG=en_US.UTF-8" > /etc/locale.conf

# Set hostname
echo "lia" > /etc/hostname

# Configure hosts
cat > /etc/hosts <<HOSTS
127.0.0.1   localhost
::1         localhost
127.0.1.1   lia.localdomain lia
HOSTS

# Set root password
echo "root:1234" | chpasswd

# Create user
useradd -m -G wheel -s /bin/bash crux
echo "crux:1234" | chpasswd

# Configure sudo
echo "%wheel ALL=(ALL:ALL) NOPASSWD: ALL" > /etc/sudoers.d/wheel

# Install and configure bootloader
pacman -S --noconfirm grub efibootmgr
grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB
grub-mkconfig -o /boot/grub/grub.cfg

# Enable services
systemctl enable NetworkManager
systemctl enable sddm
systemctl enable cups

# Install drivers
pacman -S --noconfirm xf86-video-vesa xf86-video-intel xf86-video-amdgpu xf86-video-nouveau

# Install fonts
pacman -S --noconfirm ttf-dejavu ttf-liberation noto-fonts noto-fonts-cjk

# Generate initramfs
mkinitcpio -P
EOF

# Make setup script executable
chmod +x /mnt/setup.sh

# Enter chroot and run setup script
echo "Entering chroot and running setup script..."
arch-chroot /mnt /setup.sh

# Clean up
echo "Cleaning up..."
rm /mnt/setup.sh
umount -R /mnt

echo "Installation complete!"
echo "Login credentials:"
echo "Username: crux"
echo "Password: 1234"
