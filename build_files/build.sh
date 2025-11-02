#!/bin/bash

set -ouex pipefail
cp -avf "/ctx/system_files"/. /
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
dnf -y install steam

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

#Uses Noctalia by default
systemctl mask --global dms.service
systemctl mask --global cliphist.service
systemctl unmask --global noctalia.service
systemctl enable --global noctalia.service

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
