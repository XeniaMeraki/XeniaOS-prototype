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
dnf -y install steam
dnf -y install dolphin
dnf -y install ptyxis
dnf -y install hyfetch
dnf -y install xdg-desktop-portal
dnf -y install xdg-desktop-portal-kde
dnf -y install plasma-workspace

#Uses Noctalia by default
systemctl mask --global dms.service
systemctl mask --global cliphist.service
systemctl unmask --global noctalia.service
systemctl enable --global noctalia.service

# rm /usr/share/flatpak/preinstall.d/mission-center.preinstall
# Remove any subjectively unwanted packages from Zirconium
dnf -y remove nautilus
dnf -y remove ghostty

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

ls -lah /usr/lib/modules

# Use a COPR Example:
#
# dnf5 -y copr enable ublue-os/staging
# dnf5 -y install package
# Disable COPRs so they don't end up enabled on the final image:
# dnf5 -y copr disable ublue-os/staging
