FROM base/archlinux:2015.06.01
MAINTAINER Eugen Kuksa @eugenk

# Important!  Update this no-op ENV variable when this Dockerfile
# is updated with the current date. It will force refresh of all
# of the base images when the Dockerfile is built.
ENV REFRESHED_AT 2016-02-26

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
RUN pacman -S --noconfirm base-devel pkgbuild-introspection git apache-ant ghc cabal-install openssh pkgbuild-introspection tcl tk cairo gtk2 fontconfig libglade lib32-libx11 python2
# Yet to install from AUR: udrawgraph eprover hets-lib pellet spass darwin

# Allow nobody to use sudo without password - needed for makepkg.
RUN echo "nobody ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers

# Configure git.
RUN git config --global user.email "eugenk@informatik.uni-bremen.de"
RUN git config --global user.name "Eugen Kuksa"

# Prepare Hets build.
WORKDIR /root/hets

# Clone the git repository of Hets
RUN git clone https://github.com/spechub/Hets.git hets-git

# First install all dependencies
ADD Dockerfile_aux/install_dependencies.sh /root/hets/
RUN chmod +x install_dependencies.sh
RUN /root/hets/install_dependencies.sh

# install cabal dependencies and make the hets target once for the cache
WORKDIR /root/hets/hets-git
RUN cabal update
# The cabal install step will fail for cairo with ghc > 7.8, but it is not a problem.
RUN cabal install --only-dependencies -f server -f -gtkglade -f -uniform
RUN make hets-server
WORKDIR /root/hets

# Add all other resources
# local AUR repositories of the AUR packages
VOLUME /root/hets/aur
# scripts for building and packaging
VOLUME /root/hets/build_scripts
# built packages (not yet AUR packages, but tarballs of hets binary and owl tools)
VOLUME /root/hets/packages
# resources like PKGBUILD and wrapper-script templates
VOLUME /root/hets/resources

# Open shell for interactive session.
CMD bash

# To build and create the updated package, run the following command:
# CMD /root/hets/scripts/build_and_create_updated_package.sh
