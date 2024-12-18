#!/bin/bash

# Root 권한 확인
if [ "$EUID" -ne 0 ]; then 
    echo "Please run as root"
    exit 1
fi

# 설치할 디바이스 지정
DEVICE="/dev/nvme0n1"
EFI_PART="${DEVICE}p1"
SWAP_PART="${DEVICE}p2"
ROOT_PART="${DEVICE}p3"

echo "WARNING: This will erase all data on ${DEVICE}. Are you sure? (y/N)"
read confirm
if [ "$confirm" != "y" ]; then
    echo "Aborted"
    exit 1
fi

# 기존 파티션 언마운트 및 스왑 비활성화
swapoff -a
umount -R /mnt 2>/dev/null

# 디스크 시그니처 제거
wipefs -a ${DEVICE}

# 파티션 생성
echo "Creating partitions..."
(
echo g
echo n
echo 1
echo
echo +1G
echo n
echo 2
echo
echo +8G
echo n
echo 3
echo
echo
echo t
echo 1
echo 1
echo t
echo 2
echo 19
echo w
) | fdisk ${DEVICE}

sleep 3

# 파티션 포맷
echo "Formatting partitions..."
mkfs.fat -F32 ${EFI_PART}
mkswap ${SWAP_PART}
mkfs.ext4 ${ROOT_PART}

# 마운트
echo "Mounting partitions..."
mount ${ROOT_PART} /mnt
mkdir -p /mnt/boot
mount ${EFI_PART} /mnt/boot
swapon ${SWAP_PART}

echo "Partitioning and mounting completed successfully"
lsblk ${DEVICE}

# 기본 시스템 및 KDE Plasma 설치
echo "Installing base system and KDE Plasma..."
pacstrap /mnt/arch base linux linux-firmware base-devel networkmanager vim sudo \
    xorg plasma plasma-wayland-session kde-applications \
    sddm firefox konsole dolphin kate \
    pulseaudio pulseaudio-alsa alsa-utils \
    cups cups-pdf \
    git wget

# fstab 생성
echo "Generating fstab..."
genfstab -U /mnt/arch >> /mnt/arch/etc/fstab

# chroot 설정 스크립트 생성
cat > /mnt/arch/setup.sh <<EOF
#!/bin/bash

# 시간대 설정
ln -sf /usr/share/zoneinfo/Europe/Stockholm /etc/localtime
hwclock --systohc

# 로케일 설정 부분을 다음과 같이 수정
echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen
echo "ko_KR.UTF-8 UTF-8" >> /etc/locale.gen
locale-gen
echo "LANG=en_US.UTF-8" > /etc/locale.conf

# 호스트네임 설정
echo "archlinux" > /etc/hostname

# hosts 파일 설정
echo "127.0.0.1 localhost" > /etc/hosts
echo "::1       localhost" >> /etc/hosts
echo "127.0.1.1 archlinux.localdomain archlinux" >> /etc/hosts

# root 비밀번호 설정
echo "1234" | chpasswd

# 일반 사용자 생성 (crux)
useradd -m -G wheel -s /bin/bash crux
echo "crux:1234" | chpasswd

# sudo 설정
echo "%wheel ALL=(ALL) ALL" > /etc/sudoers.d/wheel

# 부트로더 설치
pacman -S --noconfirm grub efibootmgr
grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB
grub-mkconfig -o /boot/grub/grub.cfg

# 서비스 활성화
systemctl enable NetworkManager
systemctl enable sddm
systemctl enable cups

# 드라이버 설치
pacman -S --noconfirm xf86-video-vesa xf86-video-intel xf86-video-amdgpu xf86-video-nouveau

# 추가 KDE 설정
# 터미널 폰트 설정
mkdir -p /usr/share/fonts/TTF
pacman -S --noconfirm ttf-dejavu ttf-liberation noto-fonts

# 한글 폰트 추가
pacman -S --noconfirm noto-fonts-cjk

# initramfs 생성
mkinitcpio -P

EOF

# 스크립트에 실행 권한 부여
chmod +x /mnt/arch/setup.sh

# chroot로 진입하여 설정 스크립트 실행
echo "Entering chroot and running setup script..."
arch-chroot /mnt/arch ./setup.sh

# 정리
echo "Cleaning up..."
rm /mnt/arch/setup.sh
umount -R /mnt/arch

echo "Installation complete! You can now move the SSD to another notebook and boot it."
echo "Login credentials:"
echo "Username: crux"
echo "Password: 1234"
