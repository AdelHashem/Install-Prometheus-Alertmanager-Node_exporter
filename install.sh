#!/bin/sh

#####################################################################################
#                            A script to install Prometheus                         #
# Coded by: Adel Hashem                                                             #
# Repo: https://github.com/AdelHashem/Install-Prometheus-Alertmanager-Node_exporter #
# Email: adel.mohamed.9998@gmail.com                                                #
#####################################################################################

#set -x
# Variables
GITHUB_PROMETHEUS=https://api.github.com/repos/prometheus/prometheus/releases/latest
GITHUB_ALERTMANAGER=https://api.github.com/repos/prometheus/alertmanager/releases/latest
GITHUB_NODE_EXPORTER=https://api.github.com/repos/prometheus/node_exporter/releases/latest
PROMETHEUS_SERVICE_FILE=/etc/systemd/system/prometheus.service
ALERTMANAGER_FILE=/etc/systemd/system/alertmanager.service
NODE_EXPORTER_FILE=/etc/systemd/system/node_exporter.service

# Functions

# setup the temporary directory and cleanup function
SetUp() {
    TMP_DIR=$(mktemp -d -t Prometheus-install.XXXXXXXXXX)
    PROMETHEUS_TAR=${TMP_DIR}/prometheus.tar.gz
    ALERTMANAGER_TAR=${TMP_DIR}/alertmanager.tar.gz
    NODE_EXPORTER_TAR=${TMP_DIR}/node_exporter.tar.gz
    cleanup() {
        code=$?
        INFO "Cleaning up..."
        [ -d ${TMP_DIR} ] && rm -rf ${TMP_DIR}
        exit $?
    }
    trap cleanup INT TERM EXIT
}

# Verify the system requirements
VerifySys() {
    INFO "Verifying system requirements..."
    code=0
    if ! command -v tar &>/dev/null; then
        echo "tar is required. Please install tar and try again"
        code=1
    fi
    if ! command -v curl &>/dev/null; then
        echo "curl is required. Please install curl and try again"
        code=1
    fi
    if ! command -v jq &>/dev/null; then
        echo "jq is required. Please install jq and try again"
        code=1
    fi
    if [ $code -ne 0 ]; then
        exit 1
    fi
}

# Verify the system architecture
Verify_arch() {
    INFO "Verifying system architecture..."
    ARCH=$(uname -m)
    case $ARCH in
        386)
            ARCH=386
            ;;
        amd64)
            ARCH=amd64
            ;;
        x86_64)
            ARCH=amd64
            ;;
        arm64)
            ARCH=arm64
            ;;
        s390x)
            ARCH=s390x
            ;;
        aarch64)
            ARCH=arm64
            ;;
        armv5*)
            ARCH=armv5
            ;;
        armv6*)
            ARCH=armv6
            ;;
        armv7*)
            ARCH=armv7
            ;;
        mips64)
            ARCH=mips64
            ;;
        mips64le)
            ARCH=mips64le
            ;;
        mipsle)
            ARCH=mipsle
            ;;
        mips)
            ARCH=mips
            ;;
        ppc64)
            ARCH=ppc64
            ;;
        ppc64le)
            ARCH=ppc64le
            ;;
        riscv64)
            ARCH=riscv64
            ;;
        *)
            echo "Unsupported architecture $ARCH"
            exit 1
    esac
}

# Create system user
create_sysem_user() {
    INFO "Creating user ${1}..."
    if id $1 &>/dev/null; then
        INFO "User ${1} already exists"
    else
        groupadd --system $1
        useradd --shell /sbin/nologin --system -g $1 $1
    fi
}

# Get the latest release from the GitHub API
Get_Last_Release() {
    Last_RELEASE=$(curl --location ${1} \
    --header 'Accept: application/vnd.github+json' \
    --header 'X-GitHub-Api-Version: 2022-11-28')
    if [ $? -ne 0 ]; then
        exit 1
    fi
}

# Extract the download URL from the release
Get_Download_URL() {
    URL=$(echo -n ${Last_RELEASE} | jq --raw-output ".assets[] | .browser_download_url | capture(\"(?<link>.*linux-${ARCH}.*)\") | .link")
    if [ $? -ne 0 ]; then
        exit 1
    fi
}

Download_From_URL() {
    INFO "Downloading from ${URL}"
    curl -L -o $1 ${URL} || {
        echo "Failed to download the file"
        exit 1
    }
}

# --- Functions For Prometheus ---
# --- write systemd service file for prometheus ---
create_systemd_service_file_prometheus() {
    INFO "Writing the systemd service for Prometheus"
    tee ${PROMETHEUS_SERVICE_FILE} >/dev/null << EOF
[Unit]
Description=Prometheus
Documentation=https://prometheus.io/docs/introduction/overview/
Wants=network-online.target
After=network-online.target

[Service]
Type=simple
User=prometheus
Group=prometheus
ExecReload=/bin/kill -HUP $MAINPID
ExecStart=/usr/local/bin/prometheus \\
  --config.file=/etc/prometheus/prometheus.yml \\
  --storage.tsdb.path=/var/lib/prometheus \\
  --web.console.templates=/etc/prometheus/consoles \\
  --web.console.libraries=/etc/prometheus/console_libraries \\
  --web.listen-address=0.0.0.0:9090 \\

SyslogIdentifier=prometheus
Restart=always

[Install]
WantedBy=multi-user.target
EOF
}

# install prometheus
install_prometheus() {
    INFO "Installing Prometheus..."

    Get_Last_Release ${GITHUB_PROMETHEUS}
    Get_Download_URL
    Download_From_URL ${PROMETHEUS_TAR}
    PROMETHEUS_TEMP_DIRE=${TMP_DIR}/$(tar -tf ${PROMETHEUS_TAR} | sed -n "1 p")
    tar -xzf ${PROMETHEUS_TAR} -C ${TMP_DIR}

    create_sysem_user prometheus

    set -e
    mkdir -p /etc/prometheus /var/lib/prometheus
    mv ${PROMETHEUS_TEMP_DIRE}prometheus /usr/local/bin/
    mv ${PROMETHEUS_TEMP_DIRE}promtool /usr/local/bin/
    mv ${PROMETHEUS_TEMP_DIRE}consoles /etc/prometheus
    mv ${PROMETHEUS_TEMP_DIRE}console_libraries /etc/prometheus
    mv ${PROMETHEUS_TEMP_DIRE}prometheus.yml /etc/prometheus
    chown prometheus:prometheus /usr/local/bin/prometheus
    chown prometheus:prometheus /usr/local/bin/promtool
    chown -R prometheus:prometheus /etc/prometheus /var/lib/prometheus
    create_systemd_service_file_prometheus
    set +e

    INFO "deamon-relaod"
    systemctl daemon-reload
    INFO "Enable Prometheus"
    systemctl enable prometheus
    INFO "Start Prometheus"
    systemctl start prometheus
}

# --- Functions for AlertManager
# --- write systemd service file for alertmanager ---
create_systemd_service_file_alertmanager() {
    INFO "Writing the systemd service for Alertmanager"
    tee ${ALERTMANAGER_FILE} >/dev/null << EOF
[Unit]
Description=Alertmanager for prometheus
Wants=network-online.target
After=network-online.target

[Service]
Restart=always
Type=simple
User=alertmanager
Group=alertmanager
ExecStart=/usr/local/bin/alertmanager \\
          --config.file=/etc/alertmanager/alertmanager.yml \\
          --storage.path=/var/lib/alertmanager/
            
ExecReload=/bin/kill -HUP $MAINPID
SyslogIdentifier=alertmanager
Restart=always
SendSIGKILL=no

[Install]
WantedBy=multi-user.target
EOF
}

# Install AlertManager
install_alertmanager() {
    INFO "Installing AlertManager..."

    Get_Last_Release ${GITHUB_ALERTMANAGER}
    Get_Download_URL
    Download_From_URL ${ALERTMANAGER_TAR}
    ALERTMANAGER_TEMP_DIRE=${TMP_DIR}/$(tar -tf ${ALERTMANAGER_TAR} | sed -n "1 p")
    tar -xzf ${ALERTMANAGER_TAR} -C ${TMP_DIR}

    create_sysem_user alertmanager

    set -e
    mkdir -p /etc/alertmanager /var/lib/alertmanager
    mv ${ALERTMANAGER_TEMP_DIRE}alertmanager /usr/local/bin/
    mv ${ALERTMANAGER_TEMP_DIRE}amtool /usr/local/bin/
    mv ${ALERTMANAGER_TEMP_DIRE}alertmanager.yml /etc/alertmanager
    chown alertmanager:alertmanager /usr/local/bin/alertmanager
    chown alertmanager:alertmanager /usr/local/bin/amtool
    chown -R alertmanager:alertmanager /etc/alertmanager /var/lib/alertmanager
    create_systemd_service_file_alertmanager
    set +e

    INFO "deamon-relaod"
    systemctl daemon-reload
    INFO "Enable AlertManager"
    systemctl enable alertmanager
    INFO "Start AlertManager"
    systemctl start alertmanager
}

# --- Functions For Node_Exporter ---
# --- write systemd service file for alertmanager ---
create_systemd_service_file_node_exporter() {
    INFO "Writing the systemd service for Node Exporter"
    tee ${NODE_EXPORTER_FILE} >/dev/null << EOF
[Unit]
Description=Node Exporter for prometheus
Documentation=https://prometheus.io/docs/guides/node-exporter/
Wants=network-online.target
After=network-online.target

[Service]
Restart=always
Type=simple
User=node_exporter
Group=node_exporter
ExecStart=/usr/local/bin/node_exporter
            
ExecReload=/bin/kill -HUP $MAINPID
SyslogIdentifier=node_exporter
Restart=always
SendSIGKILL=no

[Install]
WantedBy=multi-user.target
EOF
}

# Install Node Exporter
install_node_exporter() {
    INFO "Installing Node Exporter..."

    Get_Last_Release ${GITHUB_NODE_EXPORTER}
    Get_Download_URL
    Download_From_URL ${NODE_EXPORTER_TAR}
    NODE_EXPORTER_TEMP_DIRE=${TMP_DIR}/$(tar -tf ${NODE_EXPORTER_TAR} | sed -n "1 p")
    tar -xzf ${NODE_EXPORTER_TAR} -C ${TMP_DIR}

    create_sysem_user node_exporter

    set -e
    mv ${NODE_EXPORTER_TEMP_DIRE}node_exporter /usr/local/bin/
    chown node_exporter:node_exporter /usr/local/bin/node_exporter
    create_systemd_service_file_node_exporter
    set +e
    
    INFO "deamon-relaod"
    systemctl daemon-reload
    INFO "Enable Node Exporter"
    systemctl enable node_exporter
    INFO "Start Node Exporter"
    systemctl start node_exporter
}

# Print INFO messages
INFO() {
    echo -e "\e[32mINFO: $1\e[0m"
}

# usage Function
usage() {
    echo "Usage: $0 [OPTIONS]"
    echo "Options:"
    echo "  --prometheus To install Prometheus"
    echo "  --alertmanager To install alertmanager"
    echo "  --node-exporter To install Node Exporter"
}

# This script automate Prometheus installation
PROMETEHUS=
ALERTMANAGER=
NODE_EXPORTER=

# Process the input options

if [ -z "$*" ]; then usage; exit 1 ; fi

OPTS=$(getopt --options "" --longoptions 'prometheus,alertmanager,node-exporter,help' -- $@)
if [ $? != 0 ] ; then usage ; exit 1 ; fi
eval set -- "$OPTS"
while [ : ]; do
case "$1" in
        --prometheus)
            PROMETEHUS=1
             shift
            ;;
        --alertmanager)
            ALERTMANAGER=1
             shift
            ;;
        "--node-exporter")
            NODE_EXPORTER=1
            shift
            ;;
        "--help")
            usage
            exit 0
            ;;
        --)
            break
            ;;
        *)
            echo "Unrecognized option '$1'"
            usage
            exit 1
            ;;
    esac
done

# Check if the script is run as root
if [ ${UID} != 0 ]; then
    echo "This script needs to be run with sudo"
    exec sudo "$0" "$*"
fi

# The installion Process
Verify_arch
VerifySys
SetUp

if [ -n "$PROMETEHUS" ]; then
    install_prometheus
fi

if [ -n "$ALERTMANAGER" ]; then
    install_alertmanager
fi

if [ -n "$NODE_EXPORTER" ]; then
    install_node_exporter
fi

exit 0