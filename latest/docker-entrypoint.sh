# Base image
FROM python:2.7-slim-buster

# Metadata
LABEL maintainer="Ramon Bartl"
LABEL email="rb@ridingbytes.com"
LABEL senaite.core.version="v2.6.0"

# Environment variables
ENV PLONE_MAJOR=5.2 \
    PLONE_VERSION=5.2.15 \
    PLONE_MD5=714be71e21098ab148df8681196e78ce \
    PLONE_UNIFIED_INSTALLER=Plone-5.2.15-UnifiedInstaller-1.0 \
    SENAITE_HOME=/home/senaite \
    SENAITE_USER=senaite \
    SENAITE_INSTANCE_HOME=/home/senaite/senaitelims \
    SENAITE_DATA=/data \
    SENAITE_FILESTORAGE=/data/filestorage \
    SENAITE_BLOBSTORAGE=/data/blobstorage \
    SENAITE_DB_NAME=senaite_db \
    SENAITE_DB_USER=senaite_user \
    SENAITE_DB_PASS=sifre \
    SENAITE_DB_HOST=postgresql

# Create senaite user and directories
RUN useradd --system -m -d $SENAITE_HOME -U -u 500 $SENAITE_USER && \
    mkdir -p $SENAITE_INSTANCE_HOME $SENAITE_FILESTORAGE $SENAITE_BLOBSTORAGE

# Copy files
COPY requirements.txt buildout.cfg.template $SENAITE_INSTANCE_HOME/
COPY build_deps.txt run_deps.txt docker-initialize.py docker-entrypoint.sh /

# Install packages, build Plone/SENAITE and configure buildout
RUN apt-get update && \
    apt-get install -y --no-install-recommends $(grep -vE "^\s*#" /build_deps.txt | tr "\n" " ") && \
    apt-get install -y --no-install-recommends $(grep -vE "^\s*#" /run_deps.txt | tr "\n" " ") && \
    apt-get install -y gettext && \
    wget -O Plone.tgz https://launchpad.net/plone/$PLONE_MAJOR/$PLONE_VERSION/+download/$PLONE_UNIFIED_INSTALLER.tgz && \
    echo "$PLONE_MD5 Plone.tgz" | md5sum -c - && \
    tar -xzf Plone.tgz && \
    cp -rv $PLONE_UNIFIED_INSTALLER/base_skeleton/* $SENAITE_INSTANCE_HOME && \
    cp -v $PLONE_UNIFIED_INSTALLER/buildout_templates/buildout.cfg $SENAITE_INSTANCE_HOME/buildout-base.cfg && \
    envsubst < $SENAITE_INSTANCE_HOME/buildout.cfg.template > $SENAITE_INSTANCE_HOME/buildout.cfg && \
    rm -rf $PLONE_UNIFIED_INSTALLER Plone.tgz && \
    cd $SENAITE_INSTANCE_HOME && \
    pip install -r requirements.txt && \
    buildout && \
    ln -s $SENAITE_FILESTORAGE/ var/filestorage && \
    ln -s $SENAITE_BLOBSTORAGE/ var/blobstorage && \
    chown -R senaite:senaite $SENAITE_HOME $SENAITE_DATA && \
    apt-get purge -y --auto-remove $(grep -vE "^\s*#" /build_deps.txt | tr "\n" " ") gettext && \
    rm -rf /$SENAITE_HOME/buildout-cache /var/lib/apt/lists/*

# Set working directory
WORKDIR $SENAITE_INSTANCE_HOME

# Mount volume for persistence
VOLUME /data

# Expose the instance port
EXPOSE 8080

# Entrypoint and command
ENTRYPOINT ["/docker-entrypoint.sh"]
CMD ["start"]