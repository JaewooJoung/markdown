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

# Enhanced disk cleaning procedure
echo "Performing thorough disk cleanup..."

# Unmount everything first
echo "Unmounting all partitions and disabling swap..."
swapoff -a
umount -R /mnt 2>/dev/null
umount -R ${DEVICE}* 2>/dev/null

# Remove all existing partitions using dd
echo "Zeroing out the entire disk (this may take a while)..."
dd if=/dev/zero of=${DEVICE} bs=1M count=4096 status=progress
dd if=/dev/zero of=${DEVICE} bs=1M seek=4095 count=1 status=progress

# Clear any remaining signatures
echo "Clearing all remaining signatures..."
wipefs -af ${DEVICE}

# Force the kernel to reread the partition table
echo "Forcing kernel to re-read partition table..."
partprobe ${DEVICE}
sleep 2

# Create a new partition table
echo "Creating new partition table..."
sgdisk -Z ${DEVICE}
sgdisk -o ${DEVICE}

# Wait for the system to recognize the new partition table
sleep 2
partprobe ${DEVICE}
sleep 2

# Create partitions using sgdisk for GPT
echo "Creating partitions..."
sgdisk -n 1:0:+512M -t 1:ef00 ${DEVICE}  # EFI partition (increased size)
sgdisk -n 2:0:+8G -t 2:8200 ${DEVICE}    # Swap partition
sgdisk -n 3:0:0   -t 3:8300 ${DEVICE}    # Root partition

# Force kernel to reread the new partition table
echo "Updating partition table..."
partprobe ${DEVICE}
sleep 5

# Double-check that all signatures are gone before formatting
wipefs -af ${EFI_PART}
wipefs -af ${SWAP_PART}
wipefs -af ${ROOT_PART}

# Format partitions
echo "Formatting partitions..."
mkfs.fat -F32 ${EFI_PART}
mkswap -f ${SWAP_PART}
mkfs.ext4 -F ${ROOT_PART}

# Mount partitions
echo "Mounting partitions..."
mount ${ROOT_PART} /mnt
mkdir -p /mnt/boot/efi
mount ${EFI_PART} /mnt/boot/efi
swapon ${SWAP_PART}

# Install base system with added microcode
echo "Installing base system..."
pacstrap /mnt base linux linux-firmware base-devel networkmanager vim sudo \
    intel-ucode amd-ucode efibootmgr

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
pacman -S --noconfirm grub efibootmgr dosfstools os-prober mtools
mkdir -p /boot/efi
mount ${EFI_PART} /boot/efi || true  # Mount EFI partition if not already mounted

# Install GRUB for UEFI
grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=GRUB --recheck
mkdir -p /boot/grub/locale
cp /usr/share/locale/en\@quot/LC_MESSAGES/grub.mo /boot/grub/locale/en.mo

# Generate GRUB configuration
echo "GRUB_DISABLE_OS_PROBER=false" >> /etc/default/grub
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
mkin</antArtifact>
