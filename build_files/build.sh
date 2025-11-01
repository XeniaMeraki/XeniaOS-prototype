#!/bin/bash

set -ouex pipefail
cp -avf "/ctx/system_files"/. /
cp /usr/share/XeniaOS/xeniawallpaper.png /usr/share/zirconium/noctalia-shell/Assets/Wallpaper/noctalia.png
rm -rf /usr/share/zirconium/zdots
git clone https://github.com/XeniaMeraki/XeniaOS-HRT /usr/share/zirconium/zdots
### Install packages

# Packages can be installed from any enabled yum repo on the image.
# RPMfusion repos are available by default in ublue main images
# List of rpmfusion packages can be found here:
# https://mirrors.rpmfusion.org/mirrorlist?path=free/fedora/updates/39/x86_64/repoview/index.html&protocol=https&redirect=1

# this installs a package from fedora repos
dnf install https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm -y
dnf -y install dolphin
dnf -y install ptyxis
dnf -y install hyfetch
dnf -y copr enable atim/starship
dnf -y install starship

# Nuke Nautilus from orbit and replace with KDE dialogs
dnf install -y xdg-desktop-portal-kde
tee /usr/share/xdg-desktop-portal/niri-portals.conf <<'EOF'
[preferred]
default=kde;gnome;
org.freedesktop.impl.portal.ScreenCast=gnome;
org.freedesktop.impl.portal.Access=kde;
org.freedesktop.impl.portal.Notification=kde;
org.freedesktop.impl.portal.Secret=gnome-keyring;
EOF
dnf -y remove nautilus
dnf -y remove ghostty

#Dolphin file associations
dnf install -y dolphin kf5-kservice keditfiletype
ln -sf ./kf5-applications.menu /etc/xdg/menus/applications.menu
kbuildsycoca6 --noincremental

#Uses Noctalia by default
systemctl mask --global dms.service
systemctl mask --global cliphist.service
systemctl unmask --global noctalia.service
systemctl enable --global noctalia.service

# Install patched fwupd
# Install Valve's patched Mesa, Pipewire, Bluez
RUN --mount=type=cache,dst=/var/cache \
    --mount=type=cache,dst=/var/log \
    declare -A toswap=( \
        ["copr:copr.fedorainfracloud.org:bazzite-org:bazzite"]="wireplumber" \
        ["copr:copr.fedorainfracloud.org:bazzite-org:bazzite-multilib"]="pipewire bluez xorg-x11-server-Xwayland" \
        ["terra-mesa"]="mesa-filesystem" \
        ["copr:copr.fedorainfracloud.org:ublue-os:staging"]="fwupd" \
    ) && \
    for repo in "${!toswap[@]}"; do \
        for package in ${toswap[$repo]}; do dnf5 -y swap --repo=$repo $package $package; done; \
    done && unset -v toswap repo package && \
    dnf5 versionlock add \
        pipewire \
        pipewire-alsa \
        pipewire-gstreamer \
        pipewire-jack-audio-connection-kit \
        pipewire-jack-audio-connection-kit-libs \
        pipewire-libs \
        pipewire-plugin-libcamera \
        pipewire-pulseaudio \
        pipewire-utils \
        wireplumber \
        wireplumber-libs \
        bluez \
        bluez-cups \
        bluez-libs \
        bluez-obexd \
        mesa-dri-drivers \
        mesa-filesystem \
        mesa-libEGL \
        mesa-libGL \
        mesa-libgbm \
        mesa-va-drivers \
        mesa-vulkan-drivers \
        fwupd \
        fwupd-plugin-flashrom \
        fwupd-plugin-modem-manager \
        fwupd-plugin-uefi-capsule-data && \
    dnf5 -y install \
        mesa-va-drivers.i686 && \
    dnf5 -y install --enable-repo="*rpmfusion*" --disable-repo="*fedora-multimedia*" \
        libaacs \
        libbdplus \
        libbluray \
        libbluray-utils && \
    /ctx/cleanup

# Install Steam & Lutris, plus supporting packages
# Downgrade ibus to fix an issue with the Steam keyboard
RUN --mount=type=cache,dst=/var/cache \
    --mount=type=cache,dst=/var/log \
    --mount=type=secret,id=GITHUB_TOKEN \
    dnf5 versionlock add \
        ibus && \
    dnf5 -y install \
        gamescope.x86_64 \
        gamescope-libs.x86_64 \
        gamescope-libs.i686 \
        gamescope-shaders \
        jupiter-sd-mounting-btrfs \
        umu-launcher \
        dbus-x11 \
        xdg-user-dirs \
        gobject-introspection \
        libFAudio.x86_64 \
        libFAudio.i686 \
        vkBasalt.x86_64 \
        vkBasalt.i686 \
        mangohud.x86_64 \
        mangohud.i686 \
        libobs_vkcapture.x86_64 \
        libobs_glcapture.x86_64 \
        libobs_vkcapture.i686 \
        libobs_glcapture.i686 \
        VK_hdr_layer && \
    dnf5 -y --setopt=install_weak_deps=False install \
        steam \
        lutris && \
    dnf5 -y remove \
        gamemode && \
    /ctx/ghcurl "https://raw.githubusercontent.com/Winetricks/winetricks/master/src/winetricks" -Lo /usr/bin/winetricks && \
    chmod +x /usr/bin/winetricks && \
    /ctx/cleanup

#replace Fedora kernel with CachyOS kernel
rm -r -f /usr/lib/modules
dnf -y copr enable bieszczaders/kernel-cachyos
dnf -y install kernel-cachyos
dnf -y copr enable bieszczaders/kernel-cachyos-addons
dnf -y swap zram-generator-defaults cachyos-settings
dnf -y install scx-scheds-git
dnf -y install scx-manager

KERNEL_VERSION="$(find "/usr/lib/modules" -maxdepth 1 -type d ! -path "/usr/lib/modules" -exec basename '{}' ';' | sort | tail -n 1)"
export DRACUT_NO_XATTR=1
dracut --no-hostonly --kver "$KERNEL_VERSION" --reproducible --zstd -v --add ostree -f "/usr/lib/modules/$KERNEL_VERSION/initramfs.img"
chmod 0600 "/usr/lib/modules/${KERNEL_VERSION}/initramfs.img"

# Use a COPR Example:
#
# dnf5 -y copr enable ublue-os/staging
# dnf5 -y install package
# Disable COPRs so they don't end up enabled on the final image:
# dnf5 -y copr disable ublue-os/staging
