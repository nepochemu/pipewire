{ config, pkgs, unstable, ... }:
{
  
  
  imports = [
    ./hardware-configuration.nix
  ];

  services.pipewire = {
    enable = true;
    audio.enable = true;
    pulse.enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;

    extraConfig = {
      pipewire = {
        "10-quantum" = {
          "context.properties" = {
            "default.clock.quantum" = 1024;
            "default.clock.min-quantum" = 256;
            "default.clock.max-quantum" = 2048;
          };
        };
      };
      pipewire-pulse = {
        "10-disable-suspend" = {
          "pulse.properties" = {
            "module-suspend-on-idle" = false;
          };
        };
      };
    };
  };



  boot.supportedFilesystems = [ "cifs" ];

  fileSystems."/mnt/NAS/music" = {
    device = "//192.168.178.78/music";
    fsType = "cifs";
    options = [
      "credentials=/etc/samba/smb-cred"
      "vers=3.0"
      "uid=1000" "gid=1000"
      "file_mode=0644" "dir_mode=0755"
      "_netdev" "nofail"
      "x-systemd.automount"
      "x-systemd.idle-timeout=300"
    ];
  };

  # Flakes already enabled here too
  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  programs.zsh.enable = true;
  # System-wide Neovim defaults (applies to all users, including root)
  environment.etc."xdg/nvim/sysinit.vim".text = ''
    set noswapfile
    set nobackup
    set nowritebackup
  '';

  # Bootloader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.loader.systemd-boot.configurationLimit = 10;


  networking.hostName = "nixos";
  networking.networkmanager.enable = true;
  networking.firewall.allowedTCPPorts = [ 53317 ];
  networking.firewall.allowedUDPPorts = [ 53317 ];
  services.tailscale = {
    enable = true;
    package = unstable.tailscale;
    openFirewall = true;
    extraUpFlags = [ "--ssh" ];
  };

  time.timeZone = "Europe/Berlin";

  i18n.defaultLocale = "en_US.UTF-8";
  i18n.extraLocaleSettings = {
    LC_ADDRESS = "de_DE.UTF-8";
    LC_IDENTIFICATION = "de_DE.UTF-8";
    LC_MEASUREMENT = "de_DE.UTF-8";
    LC_MONETARY = "de_DE.UTF-8";
    LC_NAME = "de_DE.UTF-8";
    LC_NUMERIC = "de_DE.UTF-8";
    LC_PAPER = "de_DE.UTF-8";
    LC_TELEPHONE = "de_DE.UTF-8";
    LC_TIME = "de_DE.UTF-8";
  };

  # GNOME
  services.xserver.enable = true;
  services.displayManager.gdm.enable = true;
  services.desktopManager.gnome.enable = true;

  services.xserver.xkb = {
    layout = "us";
    variant = "";
  };

  services.printing.enable = true;

  services.pulseaudio.enable = false;
  security.rtkit.enable = true;

  users.users.airflower = {
    isNormalUser = true;
    shell = pkgs.zsh;
    description = "airflower";
    extraGroups = [ "networkmanager" "wheel" ];
    packages = with pkgs; [ ];
  };

  services.udev.enable = true;
  hardware.ledger.enable = true;
  services.udev.packages = [ pkgs.ledger-udev-rules ];
  services.udev.extraRules = ''
    # Coldcard (Coinkite)
    KERNEL=="hidraw*", ATTRS{idVendor}=="d13e", ATTRS{idProduct}=="cc10", GROUP="plugdev", MODE="0666"
  '';

  services.displayManager.autoLogin.enable = true;
  services.displayManager.autoLogin.user = "airflower";
  systemd.services."getty@tty1".enable = false;
  systemd.services."autovt@tty1".enable = false;

  programs.firefox.enable = true;
  users.defaultUserShell = pkgs.zsh;

  # Use home-manager gpg-agent to avoid double agents
  programs.gnupg.agent.enable = false;

  services.pcscd.enable = true;

  nixpkgs.config = {
    allowUnfree = true;
    permittedInsecurePackages = [
      "python3.12-ecdsa-0.19.1"
      "python3.13-ecdsa-0.19.1"
    ];
  };
  
  programs.nix-ld.enable = true;


  environment.systemPackages = with pkgs; [
    home-manager vim wget zinit git gnupg openssh pinentry-tty
    yubikey-manager pass brave neofetch lf ghostty bat telescope
    fzf xclip wl-clipboard ripgrep starship gnumake rustc cargo gcc 
    openssl pkg-config rust-analyzer rustPlatform.rustLibSrc
    openscad-unstable
    localsend nodejs_22
    

    
    
  ];

  system.autoUpgrade = {
    enable = true;
    flags = [ "-L" ];
    dates = "02:00";
    randomizedDelaySec = "45min";
  };


  security.pam.u2f = {
    enable = true;
    control = "sufficient";   # try YubiKey first, fallback to password
    settings = {
      cue = true;             # show "Please touch the device"
      authfile = "/etc/u2f_mappings";
    };
  };

  # Copy from repo (/etc/nixos/secrets/u2f_keys) → runtime (/etc/u2f_mappings)
  environment.etc."u2f_mappings".source = ../../secrets/u2f_keys;



security.sudo.extraConfig = ''
  Defaults env_keep += "SSH_AUTH_SOCK"
  Defaults env_keep += "GPG_TTY"
'';


  system.stateVersion = "25.11";
}
