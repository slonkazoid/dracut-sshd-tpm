#!/bin/sh

set -e

try_unseal() {
    tpm2_unseal -c key.ctx -p pcr:"$(cat pcrs)" -o key -S session.dat
}

cd /etc/ssh

touch key
chmod 600 key
# this is basically how systemd does it. the TPM is a nightmare machine
tpm2_pcrread
tpm2_startauthsession -S session.dat
try_unseal || tpm2_policyrestart -S session.dat &&
    try_unseal || tpm2_policyrestart -S session.dat &&
    try_unseal

for enc in *.enc; do
    base="${enc%.enc}"
    touch "$base"
    chmod 600 "$base"
    openssl aes-256-cbc -d -in "$enc" -out "$base" -kfile key -iter 1
done
