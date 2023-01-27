FROM archlinux:latest

# Add repo for ready crosscompilation libs
RUN sed -i 's|\[core\]|\[rust-crossx\]\nSigLevel = Optional TrustAll\nServer = http://astromatto.com:9001/$arch\n\n\[core\]|' /etc/pacman.conf

# Set PATH to anything that will be used to cross compile
ENV PATH=$PATH:"/opt/muslcc/arm-linux-musleabihf-cross/bin/:/home/archie/crossmac/target/bin/"

# Update all system packages and repos
RUN pacman -Syu --noconfirm

RUN pacman -S base-devel git rustup zsh nano arm-linux-gnueabihf-binutils \
    arm-linux-gnueabihf-glibc arm-linux-gnueabihf-gcc wget paru --noconfirm

# Config a new user for builds - archie
RUN sed -i 's/# %wheel ALL=(ALL:ALL) NOPASSWD: ALL/%wheel ALL=(ALL:ALL) NOPASSWD: ALL/g' /etc/sudoers
RUN useradd -m -G wheel -s /usr/bin/zsh archie
USER archie
WORKDIR /home/archie

# Install additional cross compilation libs as user archie
RUN paru -S muslcc-arm-linux-musleabihf-cross-bin aarch64-linux-musl aarch64-linux-gnu-gcc --noconfirm

# Install rust and the toolchain
RUN rustup default stable

RUN mkdir -p .cargo

# Config cargo with the right linkers for every supported target
RUN echo $'[target.aarch64-unknown-linux-gnu]\n\
linker = "aarch64-linux-gnu-gcc"\n\
[target.aarch64-unknown-linux-musl]\n\
linker = "aarch64-linux-musl-gcc"\n\
[target.armv7-unknown-linux-gnueabihf]\n\
linker = "arm-linux-gnueabihf-gcc"\n\
[target.armv7-unknown-linux-musleabihf]\n\
linker = "arm-linux-musleabihf-gcc"\n\
[target.arm-unknown-linux-gnueabihf]\n\
linker = "arm-linux-gnueabihf-gcc"\n\
[target.arm-unknown-linux-musleabihf]\n\
linker = "arm-linux-musleabihf-gcc"\n\
[target.x86_64-apple-darwin]\n\
linker = "x86_64-apple-darwin20.4-clang"\n\
[target.aarch64-apple-darwin]\n\
linker = "aarch64-apple-darwin20.4-clang"\n'\
> .cargo/config

# Add now Linux and MacOS rust targets
RUN rustup target add aarch64-unknown-linux-gnu
RUN rustup target add aarch64-unknown-linux-musl
RUN rustup target add armv7-unknown-linux-gnueabihf
RUN rustup target add armv7-unknown-linux-musleabihf
RUN rustup target add arm-unknown-linux-gnueabihf
RUN rustup target add arm-unknown-linux-musleabihf
RUN rustup target add x86_64-apple-darwin
RUN rustup target add aarch64-apple-darwin

# Install the MacOS SDK
RUN git clone https://github.com/varbhat/crossmac
RUN git clone https://github.com/tpoechtrager/osxcross
WORKDIR /home/archie/osxcross/tarballs
RUN wget https://github.com/phracker/MacOSX-SDKs/releases/download/11.3/MacOSX11.3.sdk.tar.xz
WORKDIR /home/archie/osxcross
RUN sudo pacman -S clang cmake python --noconfirm
RUN UNATTENDED=1 ./build.sh
RUN ./build_gcc.sh
RUN mv target ../crossmac
RUN rm -rf osxcross

WORKDIR /home/archie

# IMPORTANT!
# LD_LIBRARY_PATH=/home/archie/crossmac/target/lib CC=o64-clang for MacOS x64 builds
# LD_LIBRARY_PATH=/home/archie/crossmac/target/lib CC=oa64-clang cargo build --target=aarch64-apple-darwin for MacOS ARM builds
