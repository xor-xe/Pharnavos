{ pkgs, lib, user, ... }:

{
  home = {
    username = user;
    homeDirectory = "/home/${user}";
    stateVersion = "26.05";
    packages = with pkgs; [ firefox kew ];   # your own packages go here, as usual (kew: music player)
  };

  # kew asks for the music folder on first start: point it at ~/Music once (kew rewrites kewrc itself, so
  # it isn't a managed file)
  home.activation.kewLibrary = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    # (`kew path` only edits an existing kewrc; kew fills in the other settings itself)
    mkdir -p "$HOME/Music" "$HOME/.config/kew"
    [ -e "$HOME/.config/kew/kewrc" ] || echo "path=" > "$HOME/.config/kew/kewrc"
    grep -qs '^path=.' "$HOME/.config/kew/kewrc" || ${pkgs.kew}/bin/kew path "$HOME/Music" >/dev/null 2>&1 || true
  '';

  # kew's own entry runs `kew play` with no file, which plays nothing: from the launcher, open the library
  xdg.dataFile."applications/kew.desktop".text = ''
    [Desktop Entry]
    Type=Application
    Name=kew
    GenericName=Music Player
    Comment=Terminal music player for ~/Music
    Exec=kew
    Icon=kew
    Terminal=true
    Categories=Audio;Music;Player;AudioVideo;
    Keywords=music;audio;player;terminal;
  '';

  programs.pharnavos = {
    enable = true;
    terminal = "foot";
    # name = "ხორხე";

    # AI in the launcher (`?` ask, `#` translate). Off by default. With a local ollama, also turn on
    # programs.pharnavos.ai.ollama.enable in configuration.nix (downloads the model, a few GB).
    # ai = {
    #   enable = true;
    #   model = "llama3.2:3b";
    # };
  };

  programs.foot.enable = true;

  wayland.windowManager.hyprland = {
    enable = true;
    package = null;                # use the system's Hyprland (programs.hyprland)
    portalPackage = null;
    configType = "hyprlang";
    settings = {
      "$mod" = "SUPER";
      monitor = [ ",preferred,auto,1" ];
      input.kb_layout = "us,ge";
      input.kb_options = "grp:alt_shift_toggle";
      bind = [
        "$mod, Return, exec, foot"
        "$mod, Q, killactive"
        "$mod, F, fullscreen"
        "$mod, V, togglefloating"
      ] ++ builtins.concatLists (builtins.genList (i: let n = toString (i + 1); in [
        "$mod, ${n}, workspace, ${n}"
        "$mod SHIFT, ${n}, movetoworkspace, ${n}"
      ]) 9);
      bindm = [ "$mod, mouse:272, movewindow" "$mod, mouse:273, resizewindow" ];
      bindel = [
        ", XF86AudioRaiseVolume, exec, wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+"
        ", XF86AudioLowerVolume, exec, wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"
        ", XF86AudioMute, exec, wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"
      ];
    };
  };
}
