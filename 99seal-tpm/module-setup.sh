#!/bin/bash

check() {
    require_binaries m4 &&
    require_binaries bsdtar &&
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
}

seal() {
    set -e

    # archive, compress, encrypt, and copy the files we are interested in
    if ((${#files[@]} > 0)); then
        cd "${tpm_tempdir}"
        touch key ; chmod 600 key

        # generate 256-bit key
        openssl rand 32 > key

        # create TPM primary context
        tpm2_createprimary -Q -C o -c primary.ctx

        # gather PCR state
        if [ -n "${tpm_pcr_bin}" ]; then
            dinfo "copying ${tpm_pcr_bin@Q}"
            cp "${tpm_pcr_bin}" pcr.bin
        else
            dinfo "reading current PCRs"
            tpm2_pcrread -o pcr.bin "${tpm_pcrs?TPM PCR list is required}"
        fi

        # create policy with the PCR information
        tpm2_createpolicy -Q --policy-pcr -l "${tpm_pcrs}" -f pcr.bin -L pcr.policy

        # seal the encryption key in the TPM
        tpm2_create -Q -C primary.ctx -L pcr.policy -i key -c key.ctx

        bsdtar cC "${initdir}" --no-fflags "${files[@]}" |
            zstd -3c | 
            openssl aes-256-cbc -e -out "files.tar.zst.enc" -kfile "${tpm_tempdir}/key" -iter 1
        for file in "${files[@]}"; do
            rm -rf "${initdir}/${file}"
        done
        /usr/bin/install -Dm644 files.tar.zst.enc -t "${initdir}/etc/dracut-seal-tpm"
        
        # tell the TPM to persist the context in the first available slot
        tpm2_evictcontrol -C o -c key.ctx -o persistent.ctx

        # copy sealed encryption key and relevant information to the initramfs
        /usr/bin/install -Dm644 persistent.ctx "${initdir}/etc/dracut-seal-tpm/key.ctx"
        echo "pcr:${tpm_pcrs}" > "${initdir}/etc/dracut-seal-tpm/auth"
        /usr/bin/install -Dm644 pcr.bin "${initdir}/etc/dracut-seal-tpm/expected-pcr.bin"
    fi
}

install() {
    local conffile=${dracutsysrootdir}/etc/default/dracut-seal-tpm
    [ -f "${conffile}" ] && . "${conffile}"
    before=${before-}
    required_by=${required_by-}
    wanted_by=${wanted_by-}

    local tpm_tempdir=$(mktemp -d)
    chmod 700 "${tpm_tempdir}"
    ( seal ) || {
        dfatal "Couldn't seal keys!"
        rm -rf "${tpm_tempdir}"
        return 1
    }
    rm -rf "${tpm_tempdir}"

    inst_binary /usr/bin/bsdtar
    inst_binary /usr/bin/zstd
    inst_binary /usr/bin/chmod
    inst_binary /usr/bin/touch
    inst_binary /usr/bin/openssl
    inst_binary /usr/bin/basename
    inst_binary /usr/bin/tpm2_startauthsession
    inst_binary /usr/bin/tpm2_policyrestart
    inst_binary /usr/bin/tpm2_unseal
    inst_simple "${moddir}/unseal.sh" /usr/sbin/unseal.sh
    m4 --define='BEFORE'="${before}" --define='REQUIRED_BY'="${required_by}" --define='WANTED_BY'="${wanted_by}" "${moddir}/unseal.service.in" > "${initdir}${systemdsystemunitdir}/unseal.service"
    for unit in ${required_by}; do
        if [[ -z "${unit}" ]]; then continue; fi
        mkdir -p "${initdir}${systemdsystemconfdir}/${unit}.requires"
        ln -s "${systemdsystemunitdir}/unseal.service" "${initdir}${systemdsystemconfdir}/${unit}.requires"
    done
    for unit in ${wanted_by}; do
        if [[ -z "${unit}" ]]; then continue; fi
        mkdir -p "${initdir}${systemdsystemconfdir}/${unit}.wants"
        ln -s "${systemdsystemunitdir}/unseal.service" "${initdir}${systemdsystemconfdir}/${unit}.wants"
    done
}

