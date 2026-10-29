{ pkgs, lib, user, ... }:

let
  # Hyprland 0.56+ reads Lua: each bind is hl.bind(keys, dispatcher, options)
  lua = lib.generators.mkLuaInline;
  bind = keys: dsp: { _args = [ keys (lua dsp) ]; };
  bindWith = keys: dsp: opts: { _args = [ keys (lua dsp) opts ]; };
  media = { locked = true; repeating = true; };
in
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
    configType = "lua";
    settings = {
      monitor = { output = ""; mode = "preferred"; position = "auto"; scale = 1; };
      config.input = {
        kb_layout = "us,ge";
        kb_options = "grp:alt_shift_toggle";
      };
      bind = [
        (bind "SUPER + RETURN" ''hl.dsp.exec_cmd("foot")'')
        (bind "SUPER + Q" "hl.dsp.window.close()")
        (bind "SUPER + F" "hl.dsp.window.fullscreen()")
        (bind "SUPER + V" ''hl.dsp.window.float({ action = "toggle" })'')
        (bindWith "SUPER + mouse:272" "hl.dsp.window.drag()" { mouse = true; })
        (bindWith "SUPER + mouse:273" "hl.dsp.window.resize()" { mouse = true; })
        (bindWith "XF86AudioRaiseVolume" ''hl.dsp.exec_cmd("wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+")'' media)
        (bindWith "XF86AudioLowerVolume" ''hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-")'' media)
        (bindWith "XF86AudioMute" ''hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle")'' media)
      ] ++ builtins.concatLists (builtins.genList (i: let n = toString (i + 1); in [
        (bind "SUPER + ${n}" "hl.dsp.focus({ workspace = ${n} })")
        (bind "SUPER + SHIFT + ${n}" "hl.dsp.window.move({ workspace = ${n} })")
      ]) 9);
    };
  };
}
