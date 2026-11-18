set -eu
# Runs as cloud-init bootcmd on every boot, before sshd starts. The role under test runs as root and
# its output (diff, verbosity 2) ends up in public CI logs, so the secrets an image ships for
# production use are removed first:
#
# - host keys and host certificates configured in sshd: the instance gets fresh default host keys
# - apt credentials, and the apt sources whose host needs them (apt update would fail on them)
#
# The data is only deleted, not overwritten: this protects against leaks by accident, not against
# a role that recovers deleted blocks on purpose. prepare.yml checks the result.

for conf in /etc/ssh/sshd_config /etc/ssh/sshd_config.d/*.conf; do
  [ -f "$conf" ] || continue
  awk 'tolower($1) == "hostkey" || tolower($1) == "hostcertificate" { print $2 }' "$conf" |
    while read -r key; do
      case "$key" in
        /etc/ssh/ssh_host_*) ;;
        *) rm -f "$key" "$key.pub" "$key-cert.pub" ;;
      esac
    done
  sed -i -E '/^[[:space:]]*(HostKey|HostCertificate)[[:space:]]/Id' "$conf"
done
ssh-keygen -A

for auth in /etc/apt/auth.conf.d/*; do
  [ -f "$auth" ] || continue
  awk '{ for (i = 1; i < NF; i++) if ($i == "machine") print $(i + 1) }' "$auth" |
    while read -r machine; do
      host=${machine#*://}
      host=${host%%/*}
      grep -l -r -F "$host" /etc/apt/sources.list.d | xargs -r rm -f
    done
  rm -f "$auth"
done
