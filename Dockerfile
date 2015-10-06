FROM base/archlinux:2015.06.01
MAINTAINER Eugen Kuksa @eugenk

# Important!  Update this no-op ENV variable when this Dockerfile
# is updated with the current date. It will force refresh of all
# of the base images and things like `apt-get update` won't be using
# old cached versions when the Dockerfile is built.
ENV REFRESHED_AT 2015-10-06

# Set correct environment variables.
ENV HOME /root
ENV LANG en_US.UTF-8
ENV LANGUAGE en_US:en
ENV LC_ALL en_US.UTF-8

# Enable 32 bit repository - needed for udrawgraph
RUN echo "" >> /etc/pacman.conf
Run echo "[multilib]" >> /etc/pacman.conf
Run echo "Include = /etc/pacman.d/mirrorlist" >> /etc/pacman.conf

# Update and install packages needed for Hets build.
RUN pacman -Syu --noconfirm
RUN pacman -S --noconfirm base-devel ghc git apache-ant cabal-install openssh pkgbuild-introspection tcl tk cairo gtk2 fontconfig libglade lib32-libx11
# Yet to install from AUR: udrawgraph spass hets-lib pellet.

# Allow nobody to use sudo without password - needed for makepkg.
RUN echo "nobody ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers

# Configure git.
RUN git config --global user.email "eugenk@informatik.uni-bremen.de"
RUN git config --global user.name "Eugen Kuksa"

# Update Haskell packages.
RUN cabal update

# Prepare Hets build.
WORKDIR /root/hets
RUN git clone https://github.com/spechub/Hets.git hets-git

ADD hets-pkg-files/hets-wrapper-script /root/hets/hets-pkg-files/
ADD hets-pkg-files/PKGBUILD /root/hets/hets-pkg-files/

ADD scripts/install_dependencies.sh /root/hets/scripts/
ADD scripts/functions.sh /root/hets/scripts/
ADD scripts/build_hets.sh /root/hets/scripts/
ADD scripts/create_package.sh /root/hets/scripts/
ADD scripts/build_and_create_updated_package.sh /root/hets/scripts/
RUN chmod +x scripts/*

# Build Hets
VOLUME /root/hets/hets-build
RUN /root/hets/scripts/install_dependencies.sh
RUN /root/hets/scripts/build_hets.sh
RUN /root/hets/scripts/create_package.sh

# Open shell for interactive session.
CMD bash

# To build and create the updated package, run the following command:
# CMD /root/hets/scripts/build_and_create_updated_package.sh
