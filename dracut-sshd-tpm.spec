# vim: syntax=spec
Name:       dracut-sshd-tpm
Version:    {{{ git_dir_version }}}
Release:    1%{?dist}
Summary:    TPM sealing of dracut-sshd host keys
License:    MIT
URL:        https://git.slonk.ing/slonk/dracut-sshd-tpm
VCS:        {{{ git_dir_vcs }}}
Source:     {{{ git_dir_pack }}}
BuildArch:  noarch
Requires:   dracut-sshd tpm2-tools openssl

%description
Seals the SSH host keys used by dracut-sshd using the TPM,
and unseals them before sshd starts up.

%prep
{{{ git_dir_setup_macro }}}

%install
mkdir -p %{buildroot}/usr/lib/dracut/modules.d
cp -r 47sshd-tpm %{buildroot}/usr/lib/dracut/modules.d
install -Dt %{buildroot}/etc/default/dracut-sshd-tpm -m644 config 

%files
%dir /usr/lib/dracut/modules.d/47sshd-tpm
/usr/lib/dracut/modules.d/47sshd-tpm/module-setup.sh
/usr/lib/dracut/modules.d/47sshd-tpm/unseal.service
/usr/lib/dracut/modules.d/47sshd-tpm/unseal.sh
%config /etc/default/dracut-sshd-tpm

%changelog
{{{ git_dir_changelog }}}
