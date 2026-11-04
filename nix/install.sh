# Puts Pharnavos on top of an existing NixOS (KDE, GNOME…): run with
#   sudo nix --extra-experimental-features "nix-command flakes" run github:xor-xe/Pharnavos#install
# /etc/nixos/configuration.nix stays as it is; a small flake.nix next to it adds Pharnavos.

export PATH=/run/current-system/sw/bin:$PATH   # nixos-rebuild, hostname: the system's own
url=${PHARNAVOS_URL:-github:xor-xe/Pharnavos}
etc=/etc/nixos
red=$'\e[31m' bold=$'\e[1m' off=$'\e[0m'
die() { echo "${red}✗${off} $*" >&2; exit 1; }
say() { echo "${red}✚${off} $*"; }

[ -e /etc/NIXOS ] || die "This installer is for NixOS."
[ "$(id -u)" = 0 ] || die "Run it with sudo."
[ -f "$etc/configuration.nix" ] || die "No $etc/configuration.nix found."

if [ -f "$etc/flake.nix" ]; then
  grep -q "$url" "$etc/flake.nix" && die "Pharnavos is already installed. Update it with: sudo nix flake update --flake $etc && sudo nixos-rebuild switch"
  die "Your system is already a flake ($etc/flake.nix). Add Pharnavos to it yourself, see the README: https://github.com/xor-xe/Pharnavos"
fi

# the person who ran sudo, else the only user with a home
user=${SUDO_USER:-}
if [ -z "$user" ] || [ "$user" = root ]; then
  homes=(/home/*/)
  [ ${#homes[@]} = 1 ] && [ -d "${homes[0]}" ] || die "Run it with sudo from your own account."
  user=$(basename "${homes[0]}")
fi
id "$user" >/dev/null 2>&1 || die "No user $user."
host=$(hostname)

# NVIDIA (vendor 0x10de, a display controller): Turing (device 0x1e00) and newer take the open module
nvidia=null
for d in /sys/bus/pci/devices/*; do
  [ "$(cat "$d/vendor")" = 0x10de ] && [[ $(cat "$d/class") == 0x03* ]] || continue
  # ponytail: device-id cut-off, not a real generation lookup; Kepler and older aren't handled
  if (( $(cat "$d/device") >= 0x1e00 )); then nvidia='"open"'; else nvidia='"closed"'; fi
done

echo
say "${bold}Pharnavos${off} for ${bold}$user${off} on ${bold}$host${off}"
[ "$nvidia" != null ] && say "NVIDIA graphics: the proprietary driver comes along"
say "Your configuration.nix stays as it is."
keep=false
if [ -z "${PHARNAVOS_YES:-}" ]; then
  read -rp "  Keep KDE / GNOME next to Pharnavos? (no: Pharnavos only, ly login screen) [y/N] " k </dev/tty
  [[ $k == [Yy]* ]] && keep=true
  read -rp "  Install? [Y/n] " ok </dev/tty
  [[ -z $ok || $ok == [Yy]* ]] || die "Nothing changed."
fi

backup=$etc.bak-$(date +%Y%m%d-%H%M%S)
cp -a "$etc" "$backup"
cat >"$etc/flake.nix" <<EOF
{
  # Pharnavos on top of this system. Change your system in configuration.nix as usual, then:
  #   sudo nixos-rebuild switch
  # Update Pharnavos and NixOS: sudo nix flake update --flake /etc/nixos (or "update" in the launcher)
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
  inputs.pharnavos = {
    url = "$url";
    inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = { pharnavos, ... }: {
    nixosConfigurations."$host" = pharnavos.lib.system {
      user = "$user";
      nvidia = $nvidia;
      keepDesktop = $keep;   # true: KDE / GNOME stay on the login screen next to Pharnavos
      apps = ./apps.json;   # apps installed from the launcher
      modules = [ ./configuration.nix ];
    };
  };
}
EOF
echo '[]' >"$etc/apps.json"

say "Building (a few minutes; it downloads the new system)…"
export NIX_CONFIG="experimental-features = nix-command flakes"
if ! nixos-rebuild boot --flake "$etc#$host"; then
  rm -rf "$etc" && mv "$backup" "$etc"
  die "The build failed; nothing changed. Please open an issue with the output above: https://github.com/xor-xe/Pharnavos/issues"
fi
echo
say "${bold}Done.${off} Reboot, then log in: Pharnavos is the default session."
if [ "$keep" = false ]; then
  say "KDE / GNOME are off now; to bring them back, set keepDesktop = true; in $etc/flake.nix and rebuild."
fi
say "Your old setup is saved in $backup; the previous system stays in the boot menu."
