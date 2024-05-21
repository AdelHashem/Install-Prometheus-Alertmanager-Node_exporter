This repository contains a script which is used to automate the installation of Prometheus on a Linux machine.

## Prerequisites

- A Linux machine (Ubuntu, CentOS, etc.) with `jq` and `curl` installed
- User with sudo privileges

## Usage

You can run the script with the following options:

- `--prometheus`: This option triggers the installation of Prometheus.
- `--alertmanager`: This option triggers the installation of AlertManager.
- `--node-exporter`: This option triggers the installation of Node Exporter.
- `--help`: This option displays usage information.

## Example

To install Prometheus, AlertManager, and Node Exporter, you can run the script as follows:

```bash
curl -o install-prometheus.sh -L https://github.com/AdelHashem/Install-Prometheus-Alertmanager-Node_exporter/raw/main/install.sh
chmod +x install-prometheus.sh
./install-prometheus.sh --prometheus --alertmanager --node-exporter
```

Details
The script creates a systemd service for Prometheus, AlertManager, and Node Exporter, ensuring they start on boot and restart on failure. The configuration files for Prometheus and AlertManager are expected to be located at `/etc/prometheus/prometheus.yml` and `/etc/alertmanager/alertmanager.yml`, respectively.

## Note

Please ensure to check the script and modify any parameters as per your requirements before running it.
