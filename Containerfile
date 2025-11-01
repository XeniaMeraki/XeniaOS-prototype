# Allow build scripts to be referenced without being copied into the final image
FROM scratch AS ctx
COPY build_files /build_files
COPY system_files /system_files

# Base Image
FROM ghcr.io/zirconium-dev/zirconium:latest

# Install patched fwupd
# Install Valve's patched Mesa, Pipewire, Bluez, and Xwayland
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
        xorg-x11-server-Xwayland \
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

### MODIFICATIONS
## make modifications desired in your image and install packages by modifying the build.sh script
## the following RUN directive does all the things required to run "build.sh" as recommended.

RUN --mount=type=bind,from=ctx,source=/,target=/ctx \
    --mount=type=cache,dst=/var/cache \
    --mount=type=cache,dst=/var/log \
    --mount=type=tmpfs,dst=/tmp \
    /ctx/build_files/build.sh
    
RUN ls -lah /usr/lib/modules
### LINTING
## Verify final image and contents are correct.
RUN bootc container lint
