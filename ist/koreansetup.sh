#!/bin/bash

# Install required dependencies including Qt and fonts
sudo pacman -S --needed --noconfirm \
    base-devel \
    gcc \
    glib2 \
    gtk3 \
    gtk2 \
    qt5-base \
    qt4 \
    qt5-tools \
    libappindicator-gtk3 \
    libhangul \
    anthy \
    gtk-doc \
    intltool \
    git \
    automake \
    autoconf \
    libtool \
    pkg-config \
    noto-fonts-cjk \
    adobe-source-han-sans-kr-fonts \
    ttf-baekmuk

# Create directory for AUR packages
cd
rm -rf tmp-build  # Clean any previous build
mkdir -p tmp-build
cd tmp-build

# Install Korean fonts from AUR
echo "Installing Korean fonts from AUR..."

# Function to install AUR package
install_aur_package() {
    local package_name="$1"
    echo "Installing $package_name..."
    rm -rf "$package_name"
    git clone "https://aur.archlinux.org/$package_name.git"
    cd "$package_name"
    makepkg -si --noconfirm
    cd ..
}

# Install fonts from AUR
AUR_FONTS=(
    "spoqa-han-sans"
    "ttf-d2coding"
    "ttf-nanum"
    "ttf-nanumgothic_coding"
    "ttf-kopub"
    "ttf-kopubworld"
)

for font in "${AUR_FONTS[@]}"; do
    install_aur_package "$font"
done

# Download nimf source
wget https://gitlab.com/nimf-i18n/nimf/-/archive/master/nimf-master.tar.gz
tar zxf nimf-master.tar.gz
cd nimf-master

# Configure with specific options
./autogen.sh --disable-nimf-anthy --disable-nimf-m17n --disable-nimf-rime || {
    echo "Configure failed"
    exit 1
}

# Build
make || {
    echo "Make failed"
    exit 1
}

# Install
sudo make install || {
    echo "Make install failed"
    exit 1
}

sudo ldconfig

# Configure input method settings
cat > ~/.xprofile << 'EOL'
export GTK_IM_MODULE=nimf
export QT4_IM_MODULE="nimf"
export QT_IM_MODULE=nimf
export XMODIFIERS="@im=nimf"
nimf &
EOL

# Update font cache
fc-cache -fv

echo "==== Installation Complete ===="
echo "Please log out and log back in."
echo "After logging back in:"
echo "1. Run 'nimf --debug &' to start nimf with debugging"
echo "2. Run 'nimf-settings --gapplication-service &' to start the settings service"
echo "3. Use Shift+Space to switch to Korean input"
