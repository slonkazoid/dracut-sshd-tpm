# vim: syntax=spec
Name:       dracut-seal-tpm
Version:    {{{ git_dir_version }}}
Release:    1%{?dist}
Summary:    TPM sealing of files in the initramfs
License:    MIT
URL:        https://git.slonk.ing/slonk/dracut-sshd-tpm
VCS:        {{{ git_dir_vcs }}}
Source:     {{{ git_dir_pack }}}
BuildArch:  noarch
Requires:   tpm2-tools openssl bsdtar m4

%description
Seals files in the initramfs using the TPM,
and unseals them before desired services start up.

%prep
{{{ git_dir_setup_macro }}}

%install
mkdir -p %{buildroot}/usr/lib/dracut/modules.d
cp -r 99seal-tpm %{buildroot}/usr/lib/dracut/modules.d
install -Dm644 config %{buildroot}/etc/default/dracut-seal-tpm

%files
%dir /usr/lib/dracut/modules.d/99seal-tpm
/usr/lib/dracut/modules.d/99seal-tpm/module-setup.sh
/usr/lib/dracut/modules.d/99seal-tpm/unseal.service.in
/usr/lib/dracut/modules.d/99seal-tpm/unseal.sh
%config /etc/default/dracut-seal-tpm

%changelog
{{{ git_dir_changelog }}}
