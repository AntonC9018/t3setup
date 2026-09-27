{ config, lib, pkgs, ... }:

let
  cfg = config.my.t3setup;
in
{
  options.my.t3setup = {
    enable = lib.mkEnableOption "the T3 Code WSL server";

    port = lib.mkOption {
      type = lib.types.port;
      default = 9773;
      description = "Loopback port used by the NixOS T3 server.";
    };

    runtime = lib.mkOption {
      type = lib.types.str;
      default = "/home/anton/t3setup/runtime/t3";
      description = "Path to the extracted, prebuilt T3 Linux launcher.";
    };

    dataDir = lib.mkOption {
      type = lib.types.str;
      default = "/home/anton/t3setup/state/nixos";
      description = "Separate NixOS T3 state directory. Does not touch Ubuntu history.";
    };

    voiceUrl = lib.mkOption {
      type = lib.types.str;
      default = "http://127.0.0.1:8001/";
      description = "Local OpenVINO voice endpoint shared by the WSL distros.";
    };
  };

  config = lib.mkIf cfg.enable {
    # The release is a dynamically linked Linux executable, not a Nix build.
    programs.nix-ld.enable = true;
    programs.nix-ld.libraries = with pkgs; [ stdenv.cc.cc.lib zlib ];

    systemd.services.t3code = {
      description = "T3 Code WSL server";
      wantedBy = [ "multi-user.target" ];
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];
      unitConfig.ConditionPathIsExecutable = cfg.runtime;
      serviceConfig = {
        User = "anton";
        Group = "users";
        WorkingDirectory = "/home/anton/t3setup";
        ExecStart = "${cfg.runtime} serve --mode web --host 127.0.0.1 --port ${toString cfg.port} --base-dir ${cfg.dataDir}";
        Environment = [ "T3_SPEECH_OPENVINO_URL=${cfg.voiceUrl}" ];
        Restart = "on-failure";
        RestartSec = 5;
      };
    };
  };
}