FROM ubuntu:24.04

# Evita prompt interattivi durante l'installazione
ENV DEBIAN_FRONTEND=noninteractive

# Aggiorna e installa dipendenze
RUN apt-get update && apt-get install -y \
    xorriso \
    isolinux \
    syslinux \
    syslinux-utils \
    squashfs-tools \
    genisoimage \
    wget \
    rsync \
    libarchive-tools \
    && rm -rf /var/lib/apt/lists/*

# Directory di lavoro
WORKDIR /build

# Script di entrypoint
COPY docker-entrypoint.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/docker-entrypoint.sh

ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]
CMD ["/bin/bash"]
