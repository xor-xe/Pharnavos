# pharnavos-apps: installs apps from the launcher on a system set up by the one-command installer.
# The apps live in /etc/nixos/apps.json, which the system flake reads (lib.system's `apps`).
#   as you:          index | search WORD | outdated
#   as root (pkexec): install NAME [--unfree] | remove NAME | update | undo

export PATH=$PATH:/run/current-system/sw/bin   # nix, nixos-rebuild: the system's own
etc=/etc/nixos
apps=$etc/apps.json
prev=$etc/.pharnavos-prev                     # apps.json + flake.lock before the last change
cache=${XDG_CACHE_HOME:-$HOME/.cache}/pharnavos
index=$cache/packages.tsv
die() { echo "$*" >&2; exit 1; }

# the NixOS release the system follows (nixos-26.05, nixos-unstable)
channel() { jq -r '.nodes.nixpkgs.original.ref // empty' $etc/flake.lock 2>/dev/null || true; }

# root: only on a system the installer made, one change at a time
root() {
  [ "$(id -u)" = 0 ] || die "Run it through pkexec."
  grep -q apps.json $etc/flake.nix 2>/dev/null || die "This system wasn't set up by the Pharnavos installer."
  exec 9>/run/pharnavos-apps.lock
  flock -n 9 || die "Another install is still running."
  host=$(sed -n 's/.*nixosConfigurations\."\([^"]*\)".*/\1/p' $etc/flake.nix)
}
save() { mkdir -p $prev; cp $apps $etc/flake.lock $prev/; }
restore() { cp $prev/apps.json $prev/flake.lock $etc/; }
rebuild() { nixos-rebuild switch --flake "$etc#$host" 2>&1; }
name() { [[ $1 =~ ^[A-Za-z0-9_][A-Za-z0-9_.+-]*$ ]] || die "Not an app name: $1"; }
has() { jq -e --arg a "$1" 'any(.[]; .name == $a)' $apps >/dev/null; }

case ${1:-} in
  # every package of the system's NixOS release, one per line: name, version, "unfree", description.
  # Streamed (31 s, a few MB of memory) from the release's own list; refreshed weekly
  index)
    [ -n "$(find "$index" -mtime -7 2>/dev/null)" ] && exit 0
    # not made by the installer: its release by version number, or unstable (no channel by that name yet)
    ch=$(channel); ch=${ch:-nixos-$(nixos-version | cut -d. -f1-2)}
    url=https://channels.nixos.org/$ch/packages.json.br
    curl -fsIL -o /dev/null "$url" || url=https://channels.nixos.org/nixos-unstable/packages.json.br
    mkdir -p "$cache"
    curl -fsL "$url" | brotli -d \
      | jq -n --stream -r 'inputs | select(length == 2 and .[0][0] == "packages") | .[0] as $p
          | if $p[2] == "version" then [$p[1], "v", .[1]]
            elif $p[3] == "description" and ($p | length) == 4 then [$p[1], "d", .[1]]
            elif $p[3] == "license" and $p[-1] == "free" and .[1] == false then [$p[1], "u", ""]
            else empty end | map(tostring | gsub("[\t\n]"; " ")) | @tsv' \
      | awk -F'\t' 'function out() { if (a != "") print a "\t" v "\t" u "\t" d }
          $1 != a { out(); a = $1; v = u = d = "" }
          $2 == "v" { v = $3 } $2 == "d" { d = $3 } $2 == "u" { u = "unfree" } END { out() }' >"$index.tmp"
    [ -s "$index.tmp" ] || die "Couldn't download the app list."
    mv "$index.tmp" "$index"
    ;;
  search) grep -i -F -m 400 -- "$2" "$index" || true ;;
  # a newer NixOS than the one installed? (one small download)
  outdated)
    rev=$(jq -r '.nodes.nixpkgs.locked.rev // empty' $etc/flake.lock 2>/dev/null) ch=$(channel)
    [ -n "$rev" ] && [ -n "$ch" ] || exit 0
    new=$(curl -fsL "https://channels.nixos.org/$ch/git-revision") || exit 0
    if [ "$new" != "$rev" ]; then echo yes; fi
    ;;

  install)
    root; name "$2"; if has "$2"; then die "$2 is already installed."; fi
    unfree=$(nix eval --json "$etc#nixosConfigurations.$host.pkgs.$2.meta.unfree" 2>/dev/null) || die "There's no app called $2."
    if [ "$unfree" = true ] && [ "${3:-}" != --unfree ]; then die "$2 isn't free software; allow it first."; fi
    save
    jq --arg a "$2" --argjson u "$unfree" '. + [{ name: $a } + (if $u then { unfree: true } else {} end)]' $prev/apps.json >$apps
    rebuild || { restore; die "Installing $2 failed; nothing changed."; }
    ;;
  remove)
    root; name "$2"; has "$2" || die "$2 wasn't installed from the launcher."
    save
    jq --arg a "$2" 'map(select(.name != $a))' $prev/apps.json >$apps
    rebuild || { restore; die "Removing $2 failed; nothing changed."; }
    ;;
  # newest NixOS and Pharnavos; prints what changed as "CHANGE <line>"
  update)
    root; save
    old=$(readlink -f /run/current-system)
    nix flake update --flake $etc 2>&1 || die "Couldn't reach the update servers."
    rebuild || { restore; die "The update failed; nothing changed."; }
    nix store diff-closures "$old" "$(readlink -f /run/current-system)" | sed 's/\x1b\[[0-9;]*m//g; s/^/CHANGE /'
    ;;
  # back to before the last change; run again to redo it
  undo)
    root; [ -f $prev/apps.json ] || die "Nothing to undo."
    tmp=$(mktemp -d); cp $apps $etc/flake.lock "$tmp/"
    restore
    rebuild || { cp "$tmp"/* $etc/; die "Undo failed; nothing changed."; }
    cp "$tmp"/* $prev/
    ;;
  *) die "usage: pharnavos-apps index | search WORD | outdated | install NAME [--unfree] | remove NAME | update | undo" ;;
esac
