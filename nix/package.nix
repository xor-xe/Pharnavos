{ lib, stdenvNoCC, makeWrapper, quickshell, cava, networkmanager, networkmanagerapplet, blueman, power-profiles-daemon, curl, poppler-utils, procps, hyprlock }:

let
  # what the shell calls at runtime; hyprctl / systemctl / loginctl come from the system.
  # nm-connection-editor (networkmanagerapplet) and blueman-manager open from the bar's icons.
  path = lib.makeBinPath [ quickshell cava networkmanager networkmanagerapplet blueman power-profiles-daemon curl poppler-utils procps hyprlock ];
in
stdenvNoCC.mkDerivation {
  pname = "pharnavos";
  version = "0.1.0";
  src = ../shell;
  nativeBuildInputs = [ makeWrapper ];

  installPhase = ''
    runHook preInstall
    share=$out/share/pharnavos
    mkdir -p $share $out/bin
    cp -r . $share

    # `pharnavos` runs the shell; `pharnavos ipc call launcher toggle` etc. talk to it
    makeWrapper ${quickshell}/bin/qs $out/bin/pharnavos \
      --add-flags "-p $share/shell.qml" --prefix PATH : ${path}

    # the lock screen runs as its own instance, so a crash of the shell can't unlock you; if the
    # lock itself dies while locked, Hyprland keeps the session locked and hyprlock takes over
    cat > $out/bin/pharnavos-lock <<EOF
    #!/bin/sh
    export PATH=${path}:\$PATH
    # a preview locks nothing, so it never falls back to hyprlock
    [ "\$PHARNAVOS_LOCK_PREVIEW" = 1 ] && exec qs -p $share/lock.qml
    pgrep -x hyprlock >/dev/null && exit 0
    pgrep -f '$share/lock.qml' >/dev/null && exit 0
    qs -p $share/lock.qml && exit 0
    exec hyprlock
    EOF
    chmod +x $out/bin/pharnavos-lock
    runHook postInstall
  '';

  meta = {
    description = "A Georgian desktop shell for Hyprland, built on Quickshell";
    license = lib.licenses.gpl3Plus;
    platforms = lib.platforms.linux;
    mainProgram = "pharnavos";
  };
}
