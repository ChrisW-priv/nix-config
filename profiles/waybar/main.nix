{ pkgs, networkmanagerPkg, ... }:
let
  # Always use the same Nix-provided client installed by the NetworkManager module.
  nmcli = "${networkmanagerPkg}/bin/nmcli";
  wifi = pkgs.writeShellApplication {
    name = "bar-wifi";
    runtimeInputs = with pkgs; [ jq coreutils ];
    text = ''
      icon=''
      if ! ${nmcli} -t -f WIFI general >/dev/null 2>&1; then
        jq -nc --arg text "$icon" '{text:$text,tooltip:"Wi-Fi unavailable",class:"off"}'
      elif [[ $(${nmcli} -t -f WIFI general) != enabled ]]; then
        jq -nc --arg text "$icon" '{text:$text,tooltip:"Wi-Fi off · right-click to turn on",class:"off"}'
      else
        connection=$(${nmcli} -t -f TYPE,STATE,CONNECTION device status 2>/dev/null | awk -F: '$1 == "wifi" && $2 == "connected" {print $3; exit}')
        if [[ -n "$connection" ]]; then
          jq -nc --arg text "$icon" --arg tooltip "Wi-Fi: $connection · click for settings" '{text:$text,tooltip:$tooltip,class:"on"}'
        else
          jq -nc --arg text "$icon" '{text:$text,tooltip:"Wi-Fi disconnected · click for settings",class:"off"}'
        fi
      fi
    '';
  };
  wifiToggle = pkgs.writeShellApplication {
    name = "bar-wifi-toggle";
    runtimeInputs = [ ];
    text = ''
      if [[ $(${nmcli} -t -f WIFI general 2>/dev/null) == enabled ]]; then
        ${nmcli} radio wifi off
      else
        ${nmcli} radio wifi on
      fi
    '';
  };
  wifiQuick = pkgs.writeShellApplication {
    name = "bar-wifi-quick";
    runtimeInputs = [ pkgs.fuzzel pkgs.coreutils pkgs.util-linux pkgs.networkmanagerapplet ];
    text = ''
      menu() {
        fuzzel --config ${../fuzzel/fuzzel.ini} --dmenu --no-exit-on-keyboard-focus-loss \
          --anchor center --width 31 --lines 10 --minimal-lines \
          --font 'IBM Plex Sans:size=40' --prompt '> '
      }
      device=$(${nmcli} -t -f DEVICE,TYPE device status 2>/dev/null | awk -F: '$2 == "wifi" {print $1; exit}')
      if [[ -z "$device" ]]; then
        choice=$(printf '%s\n' 'No Wi-Fi adapter found' 'Detailed settings…' | menu) || exit 0
        [[ "$choice" != 'Detailed settings…' ]] || exec nm-connection-editor
        exit 0
      fi
      if [[ $(${nmcli} -t -f WIFI general 2>/dev/null) != enabled ]]; then
        choice=$(printf '%s\n' 'Wi-Fi off — right-click icon to turn on' 'Detailed settings…' | menu) || exit 0
        [[ "$choice" != 'Detailed settings…' ]] || exec nm-connection-editor
        exit 0
      fi
      # Request a fresh scan without holding up the menu; NetworkManager shows
      # cached results immediately. Reopening includes newly found networks.
      (
        exec 9>"''${XDG_RUNTIME_DIR:-/tmp}/bar-wifi-scan-$UID.lock"
        flock -n 9 || exit 0
        timeout 12 ${nmcli} device wifi rescan ifname "$device" >/dev/null 2>&1 || true
      ) >/dev/null 2>&1 &
      sleep 0.6
      active=$(${nmcli} -g GENERAL.CONNECTION device show "$device" 2>/dev/null | head -1)
      declare -A seen=()
      labels=()
      names=()
      while IFS= read -r ssid; do
        [[ -n "$ssid" && -z "''${seen[$ssid]+yes}" ]] || continue
        seen["$ssid"]=1
        if [[ "$ssid" == "$active" ]]; then labels+=("$ssid · connected")
        else labels+=("$ssid"); fi
        names+=("$ssid")
      done < <(timeout 4 ${nmcli} --escape no -g SSID device wifi list ifname "$device" --rescan no 2>/dev/null || true)
      if ((''${#labels[@]} == 0)); then labels=('No networks yet — reopen to refresh'); fi
      choice=$(printf '%s\n' "''${labels[@]}" 'Detailed settings…' | menu) || exit 0
      if [[ "$choice" == 'Detailed settings…' ]]; then exec nm-connection-editor; fi
      for i in "''${!names[@]}"; do
        [[ "$choice" == "''${labels[i]}" ]] || continue
        [[ "''${names[i]}" != "$active" ]] || exit 0
        if ! ${nmcli} device wifi connect "''${names[i]}" ifname "$device"; then
          printf '%s\n' 'Connection failed — use Detailed settings for new networks' | menu >/dev/null || true
        fi
        exit 0
      done
    '';
  };
  bluetooth = pkgs.writeShellApplication {
    name = "bar-bluetooth";
    runtimeInputs = [ pkgs.bluez pkgs.coreutils pkgs.jq ];
    text = ''
      icon=''
      if [[ ! -d /sys/class/bluetooth ]]; then
        jq -nc --arg text "$icon" '{text:$text,tooltip:"Bluetooth unavailable",class:"off"}'
      elif ! timeout 2 bluetoothctl show 2>/dev/null | grep -q 'Powered: yes'; then
        jq -nc --arg text "$icon" '{text:$text,tooltip:"Bluetooth off · right-click to turn on",class:"off"}'
      else
        jq -nc --arg text "$icon" '{text:$text,tooltip:"Bluetooth on · click for settings",class:"on"}'
      fi
    '';
  };
  bluetoothToggle = pkgs.writeShellApplication {
    name = "bar-bluetooth-toggle";
    runtimeInputs = [ pkgs.bluez pkgs.coreutils ];
    text = ''
      if timeout 2 bluetoothctl show 2>/dev/null | grep -q 'Powered: yes'; then
        timeout 3 bluetoothctl power off
      else
        timeout 3 bluetoothctl power on
      fi
    '';
  };
  volume = pkgs.writeShellApplication {
    name = "bar-volume";
    runtimeInputs = [ pkgs.pulseaudio pkgs.jq ];
    text = ''
      status=$(pactl get-sink-volume @DEFAULT_SINK@ 2>/dev/null) || {
        jq -nc '{text:"",tooltip:"Audio unavailable",class:"off"}'
        exit 0
      }
      if [[ $(pactl get-sink-mute @DEFAULT_SINK@ 2>/dev/null) == 'Mute: yes' ]]; then
        jq -nc '{text:"",tooltip:"Muted · right-click to unmute",class:"off"}'
      else
        percent=$(printf '%s\n' "$status" | awk 'match($0, /[0-9]+%/) {print substr($0, RSTART, RLENGTH); exit}')
        jq -nc --arg tooltip "Volume ''${percent:-?} · click to change output · scroll to adjust" '{text:"",tooltip:$tooltip,class:"on"}'
      fi
    '';
  };
  volumeQuick = pkgs.writeShellApplication {
    name = "bar-volume-quick";
    runtimeInputs = [ pkgs.fuzzel pkgs.pulseaudio pkgs.pavucontrol pkgs.coreutils pkgs.jq ];
    text = ''
      menu() {
        fuzzel --config ${../fuzzel/fuzzel.ini} --dmenu --no-exit-on-keyboard-focus-loss \
          --anchor center --width 31 --lines 8 --minimal-lines \
          --font 'IBM Plex Sans:size=40' --prompt '> '
      }
      current=$(pactl get-default-sink 2>/dev/null) || {
        choice=$(printf '%s\n' 'Audio unavailable' 'Detailed settings…' | menu) || exit 0
        [[ "$choice" != 'Detailed settings…' ]] || exec pavucontrol
        exit 0
      }
      labels=()
      names=()
      while IFS=$'\t' read -r name description index; do
        [[ -n "$name" ]] || continue
        if [[ "$name" == "$current" ]]; then label="$description ($index) · current"
        else label="$description ($index)"; fi
        labels+=("$label")
        names+=("$name")
      done < <(pactl --format=json list sinks 2>/dev/null |
        jq -r '.[] | [.name, (.description // .name), (.index|tostring)] | @tsv' || true)
      if ((''${#labels[@]} == 0)); then labels=('No audio outputs found'); fi
      choice=$(printf '%s\n' "''${labels[@]}" 'Detailed settings…' | menu) || exit 0
      if [[ "$choice" == 'Detailed settings…' ]]; then exec pavucontrol; fi
      for i in "''${!names[@]}"; do
        [[ "$choice" == "''${labels[i]}" ]] || continue
        sink=''${names[i]}
        pactl set-default-sink "$sink"
        # Also move streams already playing, not just future audio streams.
        while read -r input _; do
          [[ -n "$input" ]] && pactl move-sink-input "$input" "$sink" || true
        done < <(pactl list short sink-inputs)
        exit 0
      done
    '';
  };
  bluetoothSettings = pkgs.writeShellApplication {
    name = "bar-bluetooth-settings";
    runtimeInputs = [ pkgs.glib pkgs.coreutils pkgs.blueman ];
    text = ''
      # Blueman Manager requires the Blueman applet's D-Bus service, even when
      # the bar has no tray. Start it only on first use, then wait for readiness.
      ready() {
        gdbus introspect --session --dest org.blueman.Applet \
          --object-path /org/blueman/Applet >/dev/null 2>&1
      }
      if ! ready; then
        blueman-applet >/dev/null 2>&1 &
        for _ in $(seq 1 40); do
          ready && break
          sleep 0.25
        done
      fi
      if ! ready; then
        echo 'Bluetooth settings unavailable: Blueman applet did not start.' >&2
        exit 1
      fi
      exec blueman-manager
    '';
  };
  bluetoothQuick = pkgs.writeShellApplication {
    name = "bar-bluetooth-quick";
    runtimeInputs = [ pkgs.fuzzel pkgs.bluez pkgs.coreutils pkgs.gnugrep pkgs.util-linux bluetoothSettings ];
    text = ''
      menu() {
        fuzzel --config ${../fuzzel/fuzzel.ini} --dmenu --no-exit-on-keyboard-focus-loss \
          --anchor center --width 31 --lines 10 --minimal-lines \
          --font 'IBM Plex Sans:size=40' --prompt '> '
      }
      controller=$(timeout 3 bluetoothctl show 2>/dev/null) || {
        choice=$(printf '%s\n' 'No Bluetooth adapter found' 'Detailed settings…' | menu) || exit 0
        [[ "$choice" != 'Detailed settings…' ]] || exec bar-bluetooth-settings
        exit 0
      }
      if [[ "$controller" != *'Powered: yes'* ]]; then
        choice=$(printf '%s\n' 'Bluetooth off — right-click icon to turn on' 'Detailed settings…' | menu) || exit 0
        [[ "$choice" != 'Detailed settings…' ]] || exec bar-bluetooth-settings
        exit 0
      fi
      # Discovery runs in the background. The first menu shows known devices;
      # reopen it for newly discovered devices (fuzzel's input is a snapshot).
      (
        exec 9>"''${XDG_RUNTIME_DIR:-/tmp}/bar-bluetooth-scan-$UID.lock"
        flock -n 9 || exit 0
        timeout 8 bluetoothctl --timeout 7 scan on >/dev/null 2>&1 || true
      ) >/dev/null 2>&1 &
      sleep 0.6
      declare -A connected=()
      while IFS= read -r line; do
        if [[ $line =~ ^Device[[:space:]]+([[:xdigit:]:]{17})[[:space:]] ]]; then connected["''${BASH_REMATCH[1]}"]=1; fi
      done < <(timeout 3 bluetoothctl devices Connected 2>/dev/null || true)
      labels=()
      addresses=()
      while IFS= read -r line; do
        if [[ $line =~ ^Device[[:space:]]+([[:xdigit:]:]{17})[[:space:]]+(.*)$ ]]; then
          address=''${BASH_REMATCH[1]}
          name=''${BASH_REMATCH[2]//$'\t'/ }
          if [[ -n "''${connected[$address]+yes}" ]]; then labels+=("$name · connected")
          else labels+=("$name"); fi
          addresses+=("$address")
        fi
      done < <(timeout 3 bluetoothctl devices 2>/dev/null || true)
      if ((''${#labels[@]} == 0)); then labels=('No devices yet — reopen to refresh'); fi
      choice=$(printf '%s\n' "''${labels[@]}" 'Detailed settings…' | menu) || exit 0
      if [[ "$choice" == 'Detailed settings…' ]]; then exec bar-bluetooth-settings; fi
      for i in "''${!addresses[@]}"; do
        [[ "$choice" == "''${labels[i]}" ]] || continue
        address=''${addresses[i]}
        if [[ -n "''${connected[$address]+yes}" ]]; then
          bluetoothctl disconnect "$address"
        else
          bluetoothctl connect "$address" || {
            printf '%s\n' 'Connection failed — pair in Detailed settings first' | menu >/dev/null || true
          }
        fi
        exit 0
      done
    '';
  };
  power = pkgs.writeShellApplication {
    name = "bar-power-menu";
    runtimeInputs = [ pkgs.python3 pkgs.fuzzel pkgs.systemd pkgs.sway pkgs.util-linux ];
    text = ''
      export FUZZEL_CONFIG=${../fuzzel/fuzzel.ini}
      exec 9>"''${XDG_RUNTIME_DIR:-/tmp}/bar-power-menu-$UID.lock"
      flock -n 9 || exit 0
      exec python3 ${./power-menu.py}
    '';
  };
in
{
  home.packages = [ wifi wifiToggle wifiQuick bluetooth bluetoothToggle bluetoothSettings bluetoothQuick volume volumeQuick power pkgs.nerd-fonts.hack pkgs.ibm-plex ];
  xdg.configFile."waybar/top.jsonc".text = builtins.toJSON {
    layer = "top";
    position = "top";
    height = 26;
    spacing = 0;
    modules-left = [ "sway/workspaces" ];
    modules-right = [ "custom/wifi" "custom/bluetooth" "custom/volume" "clock" "custom/power" ];
    clock = { format = "{:%a %d %b  ·  %H:%M}"; tooltip-format = "{:%Y-%m-%d %H:%M:%S %Z}"; };
    "custom/wifi" = {
      exec = "${wifi}/bin/bar-wifi";
      interval = 5;
      return-type = "json";
      on-click = "${wifiQuick}/bin/bar-wifi-quick";
      on-click-right = "${wifiToggle}/bin/bar-wifi-toggle";
    };
    "custom/bluetooth" = {
      exec = "${bluetooth}/bin/bar-bluetooth";
      interval = 5;
      return-type = "json";
      on-click = "${bluetoothQuick}/bin/bar-bluetooth-quick";
      on-click-right = "${bluetoothToggle}/bin/bar-bluetooth-toggle";
    };
    "custom/volume" = {
      exec = "${volume}/bin/bar-volume";
      interval = 2;
      return-type = "json";
      on-click = "${volumeQuick}/bin/bar-volume-quick";
      on-click-right = "${pkgs.pulseaudio}/bin/pactl set-sink-mute @DEFAULT_SINK@ toggle";
      on-scroll-up = "${pkgs.pulseaudio}/bin/pactl set-sink-volume @DEFAULT_SINK@ +2%";
      on-scroll-down = "${pkgs.pulseaudio}/bin/pactl set-sink-volume @DEFAULT_SINK@ -2%";
    };
    "custom/power" = {
      format = "";
      tooltip = false;
      on-click = "${power}/bin/bar-power-menu";
    };
  };
  xdg.configFile."waybar/style.css".text = builtins.readFile ./style.css;
}
