FROM base/archlinux
MAINTAINER Eugen Kuksa @eugenk

# Important!  Update this no-op ENV variable when this Dockerfile
# is updated with the current date. It will force refresh of all
# of the base images when the Dockerfile is built.
ENV REFRESHED_AT 2017-09-14

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
RUN pacman -S --noconfirm base base-devel pkgbuild-introspection git apache-ant openssh pkgbuild-introspection tcl tk cairo gtk2 fontconfig libglade lib32-libx11 python2 zip perl stack
ENV PATH=$PATH:/usr/bin/core_perl
# Yet to install from AUR: udrawgraph eprover hets-lib pellet spass darwin

# Allow nobody to use sudo without password - needed for makepkg.
RUN echo "nobody ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers

# Configure git.
RUN git config --global user.email "hets_builder@spechub.org"
RUN git config --global user.name "Hets Builder"

RUN mkdir -p /root/hets/local
RUN mkdir -p /root/hets/host

# First install all dependencies
ADD Dockerfile_aux/install_dependencies.sh /root/hets/local/
RUN chmod +x /root/hets/local/install_dependencies.sh
RUN /root/hets/local/install_dependencies.sh

# Add all other resources from the host as a shared volume
VOLUME /root/hets/host

# Work in the host's directory
WORKDIR /root/hets/host
