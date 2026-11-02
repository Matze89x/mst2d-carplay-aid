# Build- und Testumgebung (Linux) / Build and test environment (Linux)
# Offizielles Node-22-Image (Debian bookworm) + Clang, LLD, CMake, GNU make, binutils (readelf), mksh (Test des Installers mit einer ksh-Variante).
FROM node:22-bookworm-slim
RUN apt-get update \
 && apt-get install --no-install-recommends -y clang lld cmake make binutils mksh ca-certificates \
 && rm -rf /var/lib/apt/lists/*
WORKDIR /work
