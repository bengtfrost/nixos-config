# /etc/nixos/configuration.nix
# This is now a module imported by flake.nix

# Add `inputs` to the arguments if you need to refer to flake inputs directly here.
# `pkgs` will be from the nixpkgs version pinned by the flake.
{ config, pkgs, lib, inputs, ... }:

{
  imports = [
    # Include the results of the hardware scan. This assumes hardware-configuration.nix
    # is in the same directory (/etc/nixos/)
    ./hardware-configuration.nix
  ];

  # Bootloader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.initrd.luks.devices."luks-daca4ce8-84d3-4c62-b201-917c911b8cf0".device = "/dev/disk/by-uuid/daca4ce8-84d3-4c62-b201-917c911b8cf0";

  networking.hostName = "nixos"; # Should match the name in flake.nix -> nixosConfigurations.nixos

  # Enable networking
  networking.networkmanager.enable = true;

  # Set your time zone.
  time.timeZone = "Europe/Stockholm";

  # Select internationalisation properties.
  i18n.defaultLocale = "sv_SE.UTF-8";
  i18n.extraLocaleSettings = {
    LC_ADDRESS = "sv_SE.UTF-8";
    LC_IDENTIFICATION = "sv_SE.UTF-8";
    LC_MEASUREMENT = "sv_SE.UTF-8";
    LC_MONETARY = "sv_SE.UTF-8";
    LC_NAME = "sv_SE.UTF-8";
    LC_NUMERIC = "sv_SE.UTF-8";
    LC_PAPER = "sv_SE.UTF-8";
    LC_TELEPHONE = "sv_SE.UTF-8";
    LC_TIME = "sv_SE.UTF-8";
  };

  # Enable the X11 windowing system.
  services.xserver.enable = true;

  # Enable flakes (already present, good, though flake.nix now drives the system build)
  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  # gpg key setting
  programs.gnupg.agent.enable = true;

  # System-wide Zsh. Home Manager will configure the user's Zsh.
  programs.zsh.enable = true;
  # System-wide Zsh plugin settings (for root, or default if HM doesn't override for a user)
  programs.zsh.autosuggestions.enable = true;
  programs.zsh.syntaxHighlighting.enable = true;


  # Enable the XFCE Desktop Environment.
  services.xserver.displayManager.lightdm.enable = true;
  services.xserver.desktopManager.xfce.enable = true;

  environment.sessionVariables = {
    QT_STYLE_OVERRIDE = "Adwaita-Dark";
  };

  # Configure keymap in X11
  services.xserver.xkb = {
    layout = "se";
    variant = "";
  };

  # Configure console keymap
  console.keyMap = "sv-latin1";

  # Enable CUPS to print documents.
  services.printing.enable = true;

  # Enable sound with pipewire.
  services.pulseaudio.enable = false;
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
  };

  # Define a user account. Home Manager will manage their specific environment.
  users.users.blfnix = {
    shell = pkgs.zsh; # Set the default shell; Home Manager will deeply configure it.
    isNormalUser = true;
    description = "Bengt Frost";
    extraGroups = [ "networkmanager" "wheel" ];
    packages = [ ]; # EMPTY THIS. Home Manager handles user-specific packages.
  };

  # NO explicit home-manager block here; it's configured in flake.nix

  # Install firefox.
  programs.firefox.enable = true;

  # Allow unfree packages
  nixpkgs.config.allowUnfree = true;

  # Enable autodiscovery of network printers
  services.avahi = {
  enable = true;
  nssmdns4 = true;
  openFirewall = true;
  };

  # List packages installed in system profile.
  # These are tools available to all users and for system operation.
  # User-specific dev tools will go into home.nix
  environment.systemPackages = with pkgs; [
    wget
    p7zip
    gnupg
    pinentry-tty
    curl
    fontconfig
    file
    tree
    sqlite
    xdg-utils # For xdg-open to work correctly system-wide

    # Desktop applications available system-wide
    xfce.xfce4-whiskermenu-plugin
    thunderbird
    mpv
    ffmpeg # Often a system dependency for multimedia apps
    audacious
    qbittorrent
    adwaita-qt6
    gimp3
    libreoffice
    simple-scan

    # We do NOT need 'home-manager' in systemPackages anymore.
    # The Flake (`flake.nix`) provides Home Manager and its modules during the build.
    # The `home-manager` CLI tool will be available to user `blfnix` if you
    # add `pkgs.home-manager` to their `home.packages` in `home.nix` (optional).
  ];

  fonts.packages = with pkgs; [ nerd-fonts.cousine ];

  system.stateVersion = "25.05"; 
}
