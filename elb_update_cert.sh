#!/bin/bash
# https://gist.github.com/ymkjp/4f54ecb3446fa42ff2a8

set -e
cd $(dirname $0)

# Current date YYYYMMDD_HHMMSS
DATE_CURRENT_YMD=$(date '+%Y%m%d_%H%M%S')

# AWS Profile
AWS_PROFILE=elb_update_cert

DOMAIN="__YOUR_DOMAIN__"

# Cert name prefix on IAM
CERT_NAME="letsencrypt-cert"

# ELB load balancer name
ELB_NAME="__YOUR_ELB_NAME__"

# aws-cli command
EXEC_AWS="aws --profile ${AWS_PROFILE}"

# Let's Encrypt contact email address
LE_EMAIL="__YOUR_EMAIL_ADDRESS__"

# Local path to https://github.com/letsencrypt/letsencrypt
LE_HOME="/home/ec2-user/letsencrypt"

LE_WWW_ROOT="/var/www/letsencrypt"
if [ -e "${LE_WWW_ROOT}" ]; then
    touch ${LE_WWW_ROOT}
else
    mkdir -p ${LE_WWW_ROOT}
fi

# letsencrypt-auto command
EXEC_LE_AUTO="${LE_HOME}/letsencrypt-auto --email $LE_EMAIL --agree-tos --debug"

# Path to renewed cert files
LE_FILES_ROOT=/etc/letsencrypt/live/$DOMAIN

# Symlink path to cert files
CERT_PATH=$LE_FILES_ROOT/cert.pem
CHAIN_PATH=$LE_FILES_ROOT/chain.pem
FULLCHAIN_PATH=$LE_FILES_ROOT/fullchain.pem
PRIVKEY_PATH=$LE_FILES_ROOT/privkey.pem

# Re-issue cert files
# Add `-d "__SUBDOMAIN__.${DOMAIN}"` if you need
$EXEC_LE_AUTO certonly --webroot \
        --keep-until-expiring \
        -w ${LE_WWW_ROOT} \
        -d "$DOMAIN"

if [ "${LE_FILES_ROOT}" -ot "${LE_WWW_ROOT}" ]; then
    echo "Cert files wasn't updated. Skipped uploading cert files."
    exit 0
fi

# Fetch current cert files list
OLD_SERVER_CERT_NAMES=$($EXEC_AWS iam list-server-certificates | jq -r ".ServerCertificateMetadataList[] | select(.ServerCertificateName | contains(\"${CERT_NAME}\")).ServerCertificateName")

# New cert name on IAM
NEW_SERVER_CERT_NAME="${CERT_NAME}-${DATE_CURRENT_YMD}"

# Upload certfiles to IAM
$EXEC_AWS iam upload-server-certificate --server-certificate-name $NEW_SERVER_CERT_NAME \
  --certificate-body file://$CERT_PATH \
  --private-key file://$PRIVKEY_PATH \
  --certificate-chain file://$CHAIN_PATH

# Wait for luck
sleep 5

# Fetch new cert ARN
SERVER_CERT_ARN=$($EXEC_AWS iam list-server-certificates | jq -r ".ServerCertificateMetadataList[] | select(.ServerCertificateName == \"${NEW_SERVER_CERT_NAME}\").Arn")

# Setup new cert to ELB
$EXEC_AWS elb set-load-balancer-listener-ssl-certificate \
  --load-balancer-name $ELB_NAME \
  --load-balancer-port 443 \
  --ssl-certificate-id $SERVER_CERT_ARN

# Purge previous cert
for CERT_NAME in $OLD_SERVER_CERT_NAMES; do
  $EXEC_AWS iam delete-server-certificate --server-certificate-name $CERT_NAME
done
