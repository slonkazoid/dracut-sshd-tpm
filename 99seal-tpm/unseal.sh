#!/bin/sh

set -e

try_unseal() {
    tpm2_unseal -c key.ctx -p "$(<auth)" -o key # -S session.dat
}

cd /etc/dracut-seal-tpm

if [[ ! -f files.tar.zst.enc ]]; then
    echo "nothing to do" >&2
    exit
fi

touch key
chmod 600 key
# this is basically how systemd does it. the TPM is a nightmare machine
tpm2_pcrread
tpm2_startauthsession -S session.dat
try_unseal || tpm2_policyrestart -S session.dat &&
    try_unseal || tpm2_policyrestart -S session.dat &&
    try_unseal

openssl aes-256-cbc -d -in files.tar.zst.enc -kfile key -iter 1 |
    zstd -dc |
    bsdtar xvC /
