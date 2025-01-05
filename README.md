# dracut-sshd-tpm

TPM sealing of [dracut-sshd](https://github.com/gsauthof/dracut-sshd) host keys

## Configuration

The default configuration is placed into /etc/default/dracut-sshd-tpm. You will
need to configure, at minimum, which registers to use while sealing the host
keys (the `tpm_pcrs` value).

## Building

```sh
dnf install rpkg git
git clone https://git.slonk.ing/slonk/dracut-sshd-tpm
cd dracut-sshd-tpm
rpkg local
```

The resulting package's path will be output to the console.
