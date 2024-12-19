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

# Install libayatana-appindicator
cd /tmp
git clone https://aur.archlinux.org/libayatana-appindicator.git
cd libayatana-appindicator
makepkg -si --noconfirm
cd ..

# Install nimf
cd /tmp
git clone https://aur.archlinux.org/nimf.git
cd nimf
makepkg -si --noconfirm
cd ..

# Add Korean input configuration to .xprofile
cat > ~/.xprofile << 'EOL'
export GTK_IM_MODULE=nimf
export QT4_IM_MODULE="nimf"
export QT_IM_MODULE=nimf
export XMODIFIERS="@im=nimf"
nimf &
EOL

# Install Korean fonts
sudo pacman -S --noconfirm \
    noto-fonts-cjk \
    adobe-source-han-sans-kr-fonts \
    ttf-baekmuk

echo "Setup complete. Please log out and log back in."
