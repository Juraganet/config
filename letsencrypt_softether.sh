#!/bin/bash
#
# Copyright (c) 2016 Katsuya SAITO
# This software is released under the MIT License.
# http://opensource.org/licenses/mit-license.php
#
# @(#) softethervpn_letsencrypt_cert_autoupdate.sh ver.0.1.0 2016.02.20
#
# Usage: softethervpn_letsencrypt_cert_autoupdate.sh CommonName WEBROOT PASSWORD MAIL
#
#          CommonName: Certificate common name like www.exsample.com
#          WEBROOT: HTTP Server Document root path for letsencrypt webroot plugin like /var/www/html
#          PASSWORD: SoftErther VPN Serever Administrator's password
#          MAIL: Report mail recipient email address like hoge@exsample.com
#
# Description:
#
# 
#
# 
###############################################################################

# CONFIGER SECTION #----------------------------------------------------------#

readonly LE_CMD_PATH=/usr/local/letsencrypt
readonly VPNCMD_PATH=/usr/local/vpnserver/vpncmd
readonly LOG_FILE=/var/log/vpnserver_cert_renew.log

readonly CN="$1"
readonly WEB_ROOT_PATH="$2"
readonly VPNSV_ADMIN_PASS="$3"
readonly MAIL_TO="$4"

#-----------------------------------------------------------------------------#

# SCRIPT SECTION #------------------------------------------------------------#

if [ $# != 4 ]; then
        echo "Error:"
        echo "Usage: softethervpn_letsencrypt_cert_autoupdate.sh CommonName WEBROOT PASSWORD MAIL"
        echo "         CommonName: Certificate common name like www.exsample.com"  
        echo "         WEBROOT: HTTP Server Document root path for letsencrypt webroot plugin like /var/www/html"
        echo "         PASSWORD: SoftErther VPN Serever Administrator's password"
        echo "         MAIL: Report mail recipient email address like hoge@exsample.com"
        exit 1
fi

today=`date +%F-%a-%T`
echo "# Let's Encrypt Cert autopudate Start: ${today}" >${LOG_FILE}
echo "# Update Log START ---------------------------------------------------------#" >>${LOG_FILE}

${LE_CMD_PATH}/letsencrypt-auto certonly --renew-by-default --webroot -w ${WEB_ROOT_PATH} -d ${CN} >>${LOG_FILE} 2>&1

echo >>${LOG_FILE}
echo "# SoftErther VPN SERVER CERT CHANGE LOG START ------------------------------#" >>${LOG_FILE}

${VPNCMD_PATH} \
  localhost:5555 \
  /SERVER \
  /PASSWORD:${VPNSV_ADMIN_PASS} \
  /CMD ServerCertSet \
  /LOADCERT:/etc/letsencrypt/live/${CN}/fullchain.pem \
  /LOADKEY:/etc/letsencrypt/live/${CN}/privkey.pem >>${LOG_FILE}

echo "#---------------------------- SoftErther VPN SERVER CERT CHANGE LOG END ---#" >>${LOG_FILE}
echo "#------------------------------------------------------------- Update Log END ---#" >>${LOG_FILE}

today=`date +%F-%a-%T`
echo "# Let's Encrypt Cert autopudate End: ${today}" >>${LOG_FILE}

cat ${LOG_FILE} | mail -s "[Soft Erther VPN Server Cert Auto Update] Update Report for ${CN}" ${MAIL_TO}

exit 0
#-----------------------------------------------------------------------------#
