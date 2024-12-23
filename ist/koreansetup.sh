#!/bin/bash

# Base dependencies
sudo pacman -S --needed base-devel git

# Required packages from official repos
sudo pacman -S --noconfirm \
    gobject-introspection \
    vala \
    mono \
    perl-xml-libxml \
    gtk-sharp-3

# Install cmake-extras from AUR
cd /tmp
git clone https://aur.archlinux.org/cmake-extras.git
cd cmake-extras
makepkg -si --noconfirm
cd ..

# First install wget
sudo pacman -S --noconfirm wget

# Download nimf package
wget https://github.com/hamonikr/nimf/releases/download/v1.3.8/nimf-1.3.8-1-any.pkg.tar.zst

# Install nimf
sudo pacman -U ./nimf-1.3.8-1-any.pkg.tar.zst --noconfirm

# Install Korean fonts
sudo pacman -S --noconfirm \
    noto-fonts-cjk \
    adobe-source-han-sans-kr-fonts

# Configure input method settings
cat > ~/.xprofile << 'EOL'
export GTK_IM_MODULE=nimf
export QT4_IM_MODULE="nimf"
export QT_IM_MODULE=nimf
export XMODIFIERS="@im=nimf"
nimf &
EOL

# Start nimf
nimf &
sleep 1
nimf-settings --gapplication-service &

# Cleanup downloaded package
rm nimf-1.3.8-1-any.pkg.tar.zst

# Install Korean fonts from official repos
sudo pacman -S --noconfirm \
    adobe-source-han-sans-kr-fonts \
    noto-fonts-cjk \
    ttf-baekmuk

# Install Korean fonts from AUR
cd /tmp
git clone https://aur.archlinux.org/spoqa-han-sans.git
cd spoqa-han-sans
makepkg -si --noconfirm
cd ..

git clone https://aur.archlinux.org/ttf-d2coding.git
cd ttf-d2coding
makepkg -si --noconfirm
cd ..

git clone https://aur.archlinux.org/ttf-nanum.git
cd ttf-nanum
makepkg -si --noconfirm
cd ..

git clone https://aur.archlinux.org/ttf-nanumgothic_coding.git
cd ttf-nanumgothic_coding
makepkg -si --noconfirm
cd ..

git clone https://aur.archlinux.org/ttf-kopub.git
cd ttf-kopub
makepkg -si --noconfirm
cd ..

git clone https://aur.archlinux.org/ttf-kopubworld.git
cd ttf-kopubworld
makepkg -si --noconfirm
cd ..

# Refresh font cache
fc-cache -fv

echo "Setup complete. Please log out and log back in."
