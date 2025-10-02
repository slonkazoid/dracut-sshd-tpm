#!/bin/bash

check() {
    require_binaries openssl &&
    require_binaries tpm2_createprimary &&
    require_binaries tpm2_pcrread &&
    require_binaries tpm2_createpolicy &&
    require_binaries tpm2_create &&
    require_binaries tpm2_startauthsession &&
    require_binaries tpm2_policyrestart &&
    require_binaries tpm2_unseal ||
    return 1
}

depends() {
    echo tpm2-tss
    echo sshd
}

seal() {
    set -e

    cd "$tpm_tempdir"
    touch key ; chmod 600 key

    # generate 256-bit key
    openssl rand 32 > key

    # create TPM primary context
    tpm2_createprimary -Q -C o -c primary.ctx

    # gather PCR state
    if [ -n "$tpm_pcr_bin" ]; then
        dinfo "copying ${tpm_pcr_bin@Q}"
        cp "$tpm_pcr_bin" pcr.bin
    else
        dinfo "reading current PCRs"
        tpm2_pcrread -o pcr.bin "${tpm_pcrs?TPM PCR list is required}"
    fi

    # create policy with the PCR information
    tpm2_createpolicy -Q --policy-pcr -l "$tpm_pcrs" -f pcr.bin -L pcr.policy

    # seal the encryption key in the TPM
    tpm2_create -Q -C primary.ctx -L pcr.policy -i key -c key.ctx

    # tell the TPM to persist the context in the first available slot
    tpm2_evictcontrol -C o -c key.ctx -o persistent.ctx

    # copy sealed encryption key and relevant information to the initramfs
    /usr/bin/install -Dm 644 persistent.ctx "${initdir}/etc/ssh/key.ctx"
    echo "$tpm_pcrs" > "${initdir}/etc/ssh/pcrs"

    cd "${initdir}/etc/ssh"

    # encrypt keys
    for key in ssh_host_*_key; do
        openssl aes-256-cbc -e -in "$key" -out "${key}.enc" -kfile "${tpm_tempdir}/key" -iter 1
    done
}

install() {
    local conffile=${dracutsysrootdir}/etc/default/dracut-sshd-tpm
    [ -f "$conffile" ] && . "$conffile"

    local tpm_tempdir=$(mktemp -d)
    chmod 700 "$tpm_tempdir"
    ( seal ) || {
        dfatal "Couldn't seal keys!"
        rm -rf "$tpm_tempdir"
        return 1
    }
    rm -rf "$tpm_tempdir"

    # remove unencrypted keys
    rm "$initdir"/etc/ssh/ssh_host_*_key

    inst_binary /usr/bin/touch
    inst_binary /usr/bin/chmod
    inst_binary /usr/bin/openssl
    inst_binary /usr/bin/basename
    inst_binary /usr/bin/tpm2_startauthsession
    inst_binary /usr/bin/tpm2_policyrestart
    inst_binary /usr/bin/tpm2_unseal
    inst_simple "${moddir}/unseal.sh" /usr/sbin/unseal.sh
    inst_simple "${moddir}/unseal.service" "${systemdsystemunitdir}/unseal.service"
    mkdir -p "${initdir}${systemdsystemconfdir}/sshd.service.requires"
    ln -s "${systemdsystemunitdir}/unseal.service" "${initdir}${systemdsystemconfdir}/sshd.service.requires"
}

