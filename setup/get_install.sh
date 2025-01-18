#! /bin/bash

# install node and npm, do not use nvm as sudo doesn't work with nvm well, no need to use node from nodesource, so I comment out the node source part from 04_install_keys
# setup inbount and local.inbound.conf
# setup sudoer.d/sning, so no passwd needed for sudo
# install socat
# if re-install
# sudo systemctl stop haraka.service zone-mta.service wildduck.service

BRANCH="${1:-master}"

# This script downloads all the installation files.
BASEURL="https://raw.githubusercontent.com/railty/wildduck/refs/heads/master/setup/"

## declare an array
declare -a arr=(
"00_install_global_functions_variables.sh"
"01_install_commits.sh"
"02_install_prerequisites.sh"
"03_install_check_running_services.sh"
"04_install_import_keys.sh"
"05_install_packages.sh"
"06_install_enable_services.sh"
"07_install_wildduck.sh"
"08_install_haraka.sh"
"09_install_zone_mta.sh"
"10_install_wildduck_webmail.sh"
"11_install_nginx.sh"
"12_install_ufw_rules.sh"
"13_install_ssl_certs.sh"
"14_install_start_services.sh"
"15_install_deploy.sh"
"install.sh"
)

for i in "${arr[@]}"
do
  wget -O $i ${BASEURL}$i
done

chmod +x install.sh
sudo ./install.sh abc.com mail.abc.com
