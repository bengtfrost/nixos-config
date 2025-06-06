# ❄️ Declarative NixOS with Flakes & Home Manager: A Zig Developer's Setup 🚀

Welcome! This guide details how to set up a fully declarative, reproducible NixOS system using the power of Nix Flakes, manage your user environment with Home Manager, and compile a custom development version of the Zig programming language ⚡.

This configuration is based on **NixOS 25.05 "Warbler" (Stable)**.

**Benefits:**
*   ⚙️ **Reproducibility:** Define your entire system as code and rebuild it precisely, anytime, anywhere.
*   🧹 **Clean Separation:** System configuration is distinct from user environment specifics.
*   📦 **Controlled Dependencies:** Pin exact versions of your entire software stack for consistent builds.
*   ✨ **Declarative Power:** Describe *what state* you want your system and user environment to be in, and let Nix figure out *how* to achieve it.

---

## 📜 Table of Contents

1.  [Part 1: Transitioning to a Full Flake-Managed NixOS System with Home Manager](#part-1-transitioning-to-a-full-flake-managed-nixos-system-with-home-manager)
    *   [1.1 Prerequisites & Repository Setup](#11-prerequisites--repository-setup)
    *   [1.2 Creating the System `flake.nix`](#12-creating-the-system-flakenix)
    *   [1.3 Refactoring `configuration.nix` as a Flake Module](#13-refactoring-configurationnix-as-a-flake-module)
    *   [1.4 Creating the User's Home Manager Configuration (`home.nix`)](#14-creating-the-users-home-manager-configuration-homenix)
    *   [1.5 The First System Build with Flakes & Home Manager](#15-the-first-system-build-with-flakes--home-manager)
2.  [Part 2: Customizing and Managing Your User Environment with Home Manager](#part-2-customizing-and-managing-your-user-environment-with-home-manager)
    *   [2.1 Adding and Removing User Packages (`home.packages`)](#21-adding-and-removing-user-packages-homepackages)
    *   [2.2 Advanced Shell Configuration (Zsh Example)](#22-advanced-shell-configuration-zsh-example)
    *   [2.3 Managing Application Settings (`programs.appname`)](#23-managing-application-settings-programsappname)
    *   [2.4 Managing Dotfiles (e.g., Helix Configuration)](#24-managing-dotfiles-eg-helix-configuration)
3.  [Part 3: Building a Custom Zig Development Version ⚡](#part-3-building-a-custom-zig-development-version-)
    *   [3.1 Prerequisites for Building Zig](#31-prerequisites-for-building-zig)
    *   [3.2 The Zig Build Script (`build-zig-dev.sh`)](#32-the-zig-build-script-build-zig-devsh)
    *   [3.3 Running the Build Script with `nix-shell`](#33-running-the-build-script-with-nix-shell)
    *   [3.4 Post-Build: Using Your Custom Zig](#34-post-build-using-your-custom-zig)
4.  [Part 4: System and Package Updates with Flakes 🔄](#part-4-system-and-package-updates-with-flakes-)
    *   [4.1 Understanding `flake.lock` and Flake Inputs](#41-understanding-flakelock-and-flake-inputs)
    *   [4.2 Minor Updates (within the same NixOS release)](#42-minor-updates-within-the-same-nixos-release)
    *   [4.3 Major Upgrades (to a new NixOS release)](#43-major-upgrades-to-a-new-nixos-release)
    *   [4.4 Managing Other Flake Inputs](#44-managing-other-flake-inputs)
5.  [Conclusion 🎉](#conclusion-)

---

## Part 1: Transitioning to a Full Flake-Managed NixOS System with Home Manager

This section guides you through setting up a NixOS system fully managed by Nix Flakes. This approach enhances reproducibility and simplifies dependency management. We'll integrate Home Manager to declaratively manage user-specific environments. This guide uses NixOS 25.05 "Warbler".

### 1.1 Prerequisites & Repository Setup

*   **NixOS Installed:** A working NixOS 25.05 "Warbler" installation.
*   **Flakes Enabled:** Your system's Nix configuration should have Flakes enabled. This is typically set in `/etc/nixos/configuration.nix` initially (though with a full Flake setup, Nix settings can also be managed by the Flake itself).
    ```nix
    # /etc/nixos/configuration.nix (bootstrap setting)
    { config, pkgs, ... }: {
      nix.settings.experimental-features = [ "nix-command" "flakes" ];
    }
    ```
*   **Git Repository:** It's highly recommended to manage your NixOS Flake configuration in a Git repository. This guide assumes your Flake files are located in a directory like `~/Utveckling/nixos-config/`. The system will be built by pointing `nixos-rebuild` to this directory.
    **Example Repository Structure:**
    ```
    ~/Utveckling/nixos-config/  # Your Flake repository root
    ├── flake.nix               # Defines inputs and system outputs
    ├── flake.lock              # Pins exact input versions (generated by Nix, commit this!)
    ├── configuration.nix       # Main NixOS system configuration module
    ├── hardware-configuration.nix # Hardware-specifics for your machine
    ├── users/
    │   └── blfnix.nix          # Home Manager configuration for user 'blfnix'
    ├── dotfiles/               # Optional: directory for dotfiles managed by Home Manager
    │   └── helix/
    │       └── languages.toml  # Example: Helix languages config
    └── scripts/
        └── build-zig-dev.sh    # Example: Your custom Zig build script
    ```

### 1.2 Creating the System `flake.nix`

The `flake.nix` file is the entry point for your Flake-managed system. It declares dependencies (inputs) and system configurations (outputs).

Create `~/Utveckling/nixos-config/flake.nix`:
```nix
# ~/Utveckling/nixos-config/flake.nix
{
  description = "Declarative NixOS System (User: blfnix) with Flakes & Home Manager";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.05"; # NixOS 25.05 Stable branch

    home-manager = {
      url = "github:nix-community/home-manager/release-25.05"; # HM for NixOS 25.05
      inputs.nixpkgs.follows = "nixpkgs"; # Ensures HM uses the same nixpkgs
    };
  };

  outputs = { self, nixpkgs, home-manager, ... }@inputs: {
    # Define your NixOS system(s) here
    # 'nixos' is the hostname used in this example. Replace if yours differs.
    nixosConfigurations.nixos = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux"; # Or your architecture
      specialArgs = { inherit inputs; }; # Makes 'inputs' available to modules
      modules = [
        # Import the main system configuration
        ./configuration.nix

        # Import Home Manager's NixOS module to enable it
        home-manager.nixosModules.home-manager

        # Configure Home Manager globally and for specific users
        {
          home-manager.useGlobalPkgs = true; # Allows home.nix to use system's 'pkgs'
          home-manager.useUserPackages = true;

          # Pass Flake inputs to individual home.nix files
          home-manager.extraSpecialArgs = { inherit inputs; };

          # Automatically back up existing dotfiles Home Manager wants to manage
          home-manager.backupFileExtension = "hm-bak";

          # Define user 'blfnix' and import their Home Manager configuration
          # Assumes blfnix.nix is at ./users/blfnix.nix relative to this flake.nix
          home-manager.users.blfnix = import ./users/blfnix.nix;
          # For other users:
          # home-manager.users.anotherUser = import ./users/anotherUser.nix;
        }
      ];
    };
  };
}
```

### 1.3 Refactoring `configuration.nix` as a Flake Module

Your system's `configuration.nix` (now at `~/Utveckling/nixos-config/configuration.nix`) acts as a module imported by `flake.nix`.

```nix
# ~/Utveckling/nixos-config/configuration.nix
{ config, pkgs, lib, inputs, ... }: # `inputs` is available from specialArgs

{
  imports = [ ./hardware-configuration.nix ]; # Ensure this path is correct

  # System settings (examples from your setup)
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.initrd.luks.devices."luks-daca4ce8-84d3-4c62-b201-917c911b8cf0".device = "/dev/disk/by-uuid/daca4ce8-84d3-4c62-b201-917c911b8cf0"; # Your LUKS config

  networking.hostName = "nixos"; # Should match nixosConfigurations key in flake.nix

  networking.networkmanager.enable = true;
  time.timeZone = "Europe/Stockholm";
  i18n.defaultLocale = "sv_SE.UTF-8";
  i18n.extraLocaleSettings = {
    LC_ADDRESS = "sv_SE.UTF-8"; LC_IDENTIFICATION = "sv_SE.UTF-8";
    LC_MEASUREMENT = "sv_SE.UTF-8"; LC_MONETARY = "sv_SE.UTF-8";
    LC_NAME = "sv_SE.UTF-8"; LC_NUMERIC = "sv_SE.UTF-8";
    LC_PAPER = "sv_SE.UTF-8"; LC_TELEPHONE = "sv_SE.UTF-8";
    LC_TIME = "sv_SE.UTF-8";
  };

  services.xserver.enable = true;
  services.xserver.displayManager.lightdm.enable = true;
  services.xserver.desktopManager.xfce.enable = true;
  services.xserver.xkb = { layout = "se"; variant = ""; };
  console.keyMap = "sv-latin1";

  security.rtkit.enable = true;
  services.pipewire = { enable = true; alsa.enable = true; alsa.support32Bit = true; pulse.enable = true; };
  services.pulseaudio.enable = false;

  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  users.users.blfnix = { # Your username
    shell = pkgs.zsh;
    isNormalUser = true;
    description = "Bengt Frost"; # Your name
    extraGroups = [ "networkmanager" "wheel" ];
    packages = [ ]; # IMPORTANT: User packages are managed by Home Manager
  };

  environment.systemPackages = with pkgs; [
    wget gitMinimal # Only truly system-wide essential tools
    firefox thunderbird libreoffice # Example system-wide GUI apps
  ];
  fonts.packages = with pkgs; [ nerd-fonts.cousine ];
  programs.gnupg.agent.enable = true;
  services.printing.enable = true;
  services.avahi = { enable = true; nssmdns4 = true; openFirewall = true; };
  nixpkgs.config.allowUnfree = true;

  system.stateVersion = "25.05"; # CRITICAL: Match your NixOS release
}
```
**Key adjustments:**
*   `users.users.blfnix.packages = [ ];` is essential.
*   `environment.systemPackages` is pruned; most tools are moved to Home Manager.

### 1.4 Creating the User's Home Manager Configuration (`home.nix`)

Create `~/Utveckling/nixos-config/users/blfnix.nix`. This file defines the `blfnix` user's specific environment. *(This will be the final version of your `blfnix.nix` incorporating all LSPs, Zsh settings, etc., as we refined it).*

```nix
# ~/Utveckling/nixos-config/users/blfnix.nix
{ pkgs, config, lib, inputs, ... }:

{
  home.username = "blfnix";
  home.homeDirectory = "/home/blfnix";
  home.stateVersion = "25.05";

  home.packages = with pkgs; [
    # Dev Toolchains
    rustup python313 uv nodejs_24 zig zls zsh-autocomplete
    # Build Tools
    cmake ninja llvmPackages_20.clang llvmPackages_20.llvm llvmPackages_20.lld llvmPackages_20.clang-tools
    # Editors & LSPs
    helix marksman ruff python313Packages.python-lsp-server
    nodePackages.typescript-language-server nodePackages.vscode-json-languageserver
    nodePackages.yaml-language-server dprint taplo
    # CLI Tools
    tmux pass keychain git gh fd ripgrep bat jq xclip yazi
    ueberzugpp unar ffmpegthumbnailer poppler_utils w3m zathura
  ];

  programs.zsh = {
    enable = true;
    autosuggestion.enable = true;
    syntaxHighlighting.enable = true;
    shellAliases = {
      ls = "ls --color=auto -F"; ll = "ls -alhF"; la = "ls -AF"; l  = "ls -CF";
      glog = "git log --oneline --graph --decorate --all";
      nix-update-system = "sudo nixos-rebuild switch --flake ~/Utveckling/nixos-config#nixos"; # Adjust path & hostname
      cc = "clang"; cxx = "clang++";
    };
    history = {
      size = 10000; path = "${config.xdg.dataHome}/zsh/history";
      share = true; ignoreDups = true; ignoreSpace = true; save = 10000;
    };
    initContent = ''
      bindkey -v # Enable Vi Keybindings

      # PATH Exports
      export PATH="$HOME/.cargo/bin:$PATH"   # For rustup tools & cargo install
      export PATH="$HOME/.local/bin:$PATH" # For user scripts & custom builds (like Zig dev)
      export PATH="$HOME/.npm-global/bin:$PATH" # For any global npm packages

      export KEYTIMEOUT=150 # For Vi mode ESC responsiveness

      # Custom Functions (ensure these are fully defined)
      multipull() {
        local BASE_DIR=~/.code
        if [[ ! -d "$BASE_DIR" ]]; then echo "multipull: Base dir $BASE_DIR not found" >&2; return 1; fi
        echo "Searching Git repos under $BASE_DIR..."
        fd --hidden --no-ignore --type d '^\.git$' "$BASE_DIR" | while read -r gitdir; do
          local workdir=$(dirname "$gitdir")
          echo -e "\n=== Updating $workdir ==="
          if (cd "$workdir" && git rev-parse --abbrev-ref --symbolic-full-name '@{u}' &>/dev/null); then
            git -C "$workdir" pull
          else
            local branch=$(git -C "$workdir" rev-parse --abbrev-ref HEAD)
            echo "--- Skipping pull (no upstream for branch: $branch) ---"
          fi
        done
        echo -e "\nMultipull finished."
      }
      _activate_venv() {
        local venv_name="$1"; local venv_activate_path="$2"
        if [[ ! -f "$venv_activate_path" ]]; then echo "Error: Venv script $venv_activate_path not found" >&2; return 1; fi
        [[ "$(type -t deactivate)" = "function" ]] && deactivate
        . "$venv_activate_path" && echo "Activated venv: $venv_name"
      }
      # Example venv functions:
      # v_mlmenv() { _activate_venv "mlmenv" "$HOME/.venv/mlmenv/bin/activate"; }
    '';
  };

  programs.starship.enable = true;
  programs.git = {
    enable = true; userName = "Bengt Frost"; userEmail = "bengtfrost@gmail.com"; # Your details!
    extraConfig = { core.editor = "hx"; init.defaultBranch = "main"; };
  };
  programs.helix.enable = true;
  programs.fzf = {
    enable = true; enableZshIntegration = true;
    defaultCommand = "fd --type f --hidden --follow --exclude .git";
    defaultOptions = [ "--height 40%" "--layout=reverse" "--border" "--prompt='➜  '" ];
  };
  programs.zathura = {
    enable = true;
    options = {
      selection-clipboard = "clipboard"; adjust-open = "best-fit"; default-bg = "#212121";
      default-fg = "#303030"; statusbar-fg = "#B2CCD6"; statusbar-bg = "#353535";
      inputbar-bg = "#212121"; inputbar-fg = "#FFFFFF"; notification-bg = "#212121";
      notification-fg = "#FFFFFF"; notification-error-bg = "#212121";
      notification-error-fg = "#F07178"; notification-warning-bg = "#212121";
      notification-warning-fg = "#F07178"; highlight-color = "#FFCB6B";
      highlight-active-color = "#82AAFF"; completion-bg = "#303030";
      completion-fg = "#82AAFF"; completion-highlight-fg = "#FFFFFF";
      completion-highlight-bg = "#82AAFF"; recolor-lightcolor = "#212121";
      recolor-darkcolor = "#EEFFFF"; recolor = false; recolor-keephue = false;
    };
  };

  # Example: Managing Helix's languages.toml
  # Assumes languages.toml is at ~/Utveckling/nixos-config/dotfiles/helix/languages.toml
  xdg.configFile."helix/languages.toml".source = ../dotfiles/helix/languages.toml;
  # You would similarly manage config.toml if desired:
  # xdg.configFile."helix/config.toml".source = ../dotfiles/helix/config.toml;

  home.sessionVariables = {
    EDITOR = "hx"; VISUAL = "hx"; PAGER = "less";
    CC = "clang"; CXX = "clang++"; GIT_TERMINAL_PROMPT = "1";
    FZF_ALT_C_COMMAND = "fd --type d --hidden --follow --exclude .git";
  };
}
```

### 1.5 The First System Build with Flakes & Home Manager
1.  **Navigate to your Flake directory** (e.g., `~/Utveckling/nixos-config/`).
2.  **Build and switch:**
    ```bash
    sudo nixos-rebuild switch --flake .#nixos 
    # Replace 'nixos' with your system's name from flake.nix
    ```
3.  **Troubleshooting Recap:** Refer to this guide's previous sections if you encounter errors related to purity, Home Manager activation, module options, package collisions, or `stateVersion`.
4.  **Post-Build:** Log out and log back in as `blfnix`. Initialize `rustup`:
    ```bash
    rustup default stable
    rustup component add rust-src clippy rustfmt
    ```

---

## Part 2: Customizing and Managing Your User Environment with Home Manager
Manage your user environment by editing `~/Utveckling/nixos-config/users/blfnix.nix` and running `sudo nixos-rebuild switch --flake .#nixos`.

### 2.1 Adding and Removing User Packages (`home.packages`)
Modify the `home.packages` list. Example:
```nix
home.packages = with pkgs; [ /* ... existing ... */ neofetch htop ];
```

### 2.2 Advanced Shell Configuration (Zsh Example)
Modify `programs.zsh = { ... };` for aliases, functions, etc.
```nix
programs.zsh.shellAliases.k = "kubectl";
programs.zsh.initContent = ''
  # ... existing ...
  setopt extended_glob # New Zsh option
  my_new_function() { echo "Hello from Zsh!"; }
'';
```

### 2.3 Managing Application Settings (`programs.appname`)
Use Home Manager modules like `programs.starship` or `programs.git`.
```nix
programs.starship = {
  enable = true;
  # To use a custom starship.toml from your Flake repo:
  # settings = builtins.fromTOML (builtins.readFile ../dotfiles/starship.toml);
};
```

### 2.4 Managing Dotfiles (e.g., Helix Configuration)
Use `xdg.configFile` for files in `~/.config/` or `home.file` for files in `~`.
**Example for Helix:**
1.  Place your `languages.toml` at `~/Utveckling/nixos-config/dotfiles/helix/languages.toml`.
2.  Place your `config.toml` at `~/Utveckling/nixos-config/dotfiles/helix/config.toml`.
3.  In `~/Utveckling/nixos-config/users/blfnix.nix`, ensure these lines are active:
    ```nix
    xdg.configFile."helix/languages.toml".source = ../dotfiles/helix/languages.toml;
    xdg.configFile."helix/config.toml".source = ../dotfiles/helix/config.toml;
    ```
    *(The `../dotfiles/` path is relative to `users/blfnix.nix` assuming `dotfiles/` is at the Flake root, e.g., `~/Utveckling/nixos-config/dotfiles/`)*.

---

## Part 3: Building a Custom Zig Development Version ⚡
Compile Zig `0.15.0-dev.669+561ab59ce` from source.

### 3.1 Prerequisites for Building Zig
Ensure `cmake`, `ninja`, `llvmPackages_20.clang` (and companions) are in `home.packages`.

### 3.2 The Zig Build Script (`build-zig-dev.sh`)
Save this script (e.g., in `~/Utveckling/nixos-config/scripts/build-zig-dev.sh`). It targets Zig `0.15.0-dev.669+561ab59ce`.

```bash
#!/usr/bin/env bash
set -euo pipefail
# --- Configuration ---
ZIG_VERSION_TO_BUILD="0.15.0-dev.669+561ab59ce"; DOWNLOAD_DIR="${PWD}"
STAGE1_TARBALL_NAME="zig-x86_64-linux-${ZIG_VERSION_TO_BUILD}.tar.xz"
SOURCE_TARBALL_NAME="zig-${ZIG_VERSION_TO_BUILD}.tar.xz" # Verify from ziglang.org/builds
BASE_DEV_DIR="${HOME}/Utveckling/Zig"
STAGE1_EXTRACTION_DIR="${BASE_DEV_DIR}/zig_compilers/zig-${ZIG_VERSION_TO_BUILD}"
STAGE1_ZIG_COMPILER_PATH="${STAGE1_EXTRACTION_DIR}/zig"
SOURCE_EXTRACTION_DIR="${BASE_DEV_DIR}/zig_source/zig-${ZIG_VERSION_TO_BUILD}"
FINAL_INSTALL_PREFIX="${HOME}/.local/zig-${ZIG_VERSION_TO_BUILD}"
FINAL_SYMLINK_NAME="zig-${ZIG_VERSION_TO_BUILD}"
FINAL_SYMLINK_PATH="${HOME}/.local/bin/${FINAL_SYMLINK_NAME}"
# --- Args ---
REBUILD_ARTIFACTS=false; CHECK_AFTER_BUILD=false; OPTIMIZE_LEVEL="ReleaseFast"; ADDITIONAL_ZIG_BUILD_OPTIONS=()
while [[ $# -gt 0 ]]; do case "$1" in --check) CHECK_AFTER_BUILD=true;; --rebuild-artifacts) REBUILD_ARTIFACTS=true;; --optimize=*) OPTIMIZE_LEVEL="${1#*=}";; -D*) ADDITIONAL_ZIG_BUILD_OPTIONS+=("$1");; *) echo "❌ Unk opt: $1";exit 1;; esac; shift; done
# --- Prep ---
echo "➡️ Prep Zig: ${ZIG_VERSION_TO_BUILD}"; if [ ! -f "${DOWNLOAD_DIR}/${STAGE1_TARBALL_NAME}" ]; then echo "❌ Stage1 not found"; exit 1; fi; if [ ! -f "${DOWNLOAD_DIR}/${SOURCE_TARBALL_NAME}" ]; then echo "❌ Source not found"; exit 1; fi
if [ "$REBUILD_ARTIFACTS" = true ]; then echo "🗑️ Clean build..."; rm -rf "$STAGE1_EXTRACTION_DIR" "$SOURCE_EXTRACTION_DIR" "$FINAL_INSTALL_PREFIX"; fi
mkdir -p "$STAGE1_EXTRACTION_DIR" "$SOURCE_EXTRACTION_DIR" "$FINAL_INSTALL_PREFIX" "$(dirname "$FINAL_SYMLINK_PATH")"
# --- Extract Stage1 ---
if [ ! -f "$STAGE1_ZIG_COMPILER_PATH" ] || [ "$REBUILD_ARTIFACTS" = true ]; then echo "📦 Extract Stage1..."; tar -xf "${DOWNLOAD_DIR}/${STAGE1_TARBALL_NAME}" -C "$STAGE1_EXTRACTION_DIR" --strip-components=1 || exit 1; echo "✅ Stage1 done."; fi
if [ ! -x "$STAGE1_ZIG_COMPILER_PATH" ]; then echo "❌ Stage1 zig not exec"; exit 1; fi; echo "ℹ️ Stage1: $($STAGE1_ZIG_COMPILER_PATH version) from $STAGE1_ZIG_COMPILER_PATH"
# --- Extract Source ---
if [ ! -f "${SOURCE_EXTRACTION_DIR}/build.zig" ] || [ "$REBUILD_ARTIFACTS" = true ]; then echo "📦 Extract Source..."; if [ "$REBUILD_ARTIFACTS" = true ]; then rm -rf "${SOURCE_EXTRACTION_DIR:?}"/*; fi; tar -xf "${DOWNLOAD_DIR}/${SOURCE_TARBALL_NAME}" -C "$SOURCE_EXTRACTION_DIR" --strip-components=1 || exit 1; echo "✅ Source done."; fi
if [ ! -f "${SOURCE_EXTRACTION_DIR}/build.zig" ]; then echo "❌ build.zig not found"; exit 1; fi
# --- Build ---
cd "$SOURCE_EXTRACTION_DIR"; if [ "$REBUILD_ARTIFACTS" = true ]; then echo "🗑️ Clean cache..."; rm -rf ./zig-cache ./zig-out; fi
echo "🏗 Building Zig ${ZIG_VERSION_TO_BUILD}..."; if [ "$REBUILD_ARTIFACTS" != true ]; then echo "🧼 Clean install dest..."; rm -rf "${FINAL_INSTALL_PREFIX:?}"/*; fi
BUILD_ARGS=(build install -p "$FINAL_INSTALL_PREFIX" "-Doptimize=${OPTIMIZE_LEVEL}" "-Dtarget=native" -Dstrip "${ADDITIONAL_ZIG_BUILD_OPTIONS[@]}")
echo "🚀 Exec: $STAGE1_ZIG_COMPILER_PATH ${BUILD_ARGS[*]}"; "$STAGE1_ZIG_COMPILER_PATH" "${BUILD_ARGS[@]}" || exit 1
# --- Post-Build ---
REBUILT_ZIG_BIN="${FINAL_INSTALL_PREFIX}/bin/zig"; if [ ! -x "$REBUILT_ZIG_BIN" ]; then echo "❌ Zig bin not found"; exit 1; fi
if [ "$CHECK_AFTER_BUILD" = true ]; then echo "🔍 Check version:"; "$REBUILT_ZIG_BIN" version; fi
echo "🔗 Symlink: $FINAL_SYMLINK_PATH -> ${REBUILT_ZIG_BIN}"; ln -sf "$REBUILT_ZIG_BIN" "$FINAL_SYMLINK_PATH"
echo "✅ Zig ${ZIG_VERSION_TO_BUILD} built!"; echo "   Version: $($REBUILT_ZIG_BIN version)"; echo "   Installed: $FINAL_INSTALL_PREFIX"; echo "   Symlink: $FINAL_SYMLINK_PATH"
echo "🔔 To make default 'zig': ln -sf \"$REBUILT_ZIG_BIN\" \"${HOME}/.local/bin/zig\""
```
*(Note: The Zig build script has been slightly condensed for brevity in the README, ensure all necessary error checks and echos are present in your actual script file.)*

### 3.3 Running the Build Script with `nix-shell`
1.  Create a temporary directory (e.g., `~/zig_build_temp`).
2.  Download the Stage1 binary (`zig-x86_64-linux-...tar.xz`) and Source code (`zig-...tar.xz`) for version `0.15.0-dev.669+561ab59ce` into this directory.
3.  Place your `build-zig-dev.sh` script there.
4.  From `~/zig_build_temp`, run:
    ```bash
    nix-shell -p pkgs.stdenv pkgs.bash \
      pkgs.llvmPackages_20.clang pkgs.llvmPackages_20.bintools \
      pkgs.cmake pkgs.ninja \
      --run "./build-zig-dev.sh"
    ```
**Why `nix-shell`?** It provides a compatible environment for the generic Linux Stage1 Zig binary and ensures the build uses Nix-provided Clang, CMake, etc.

### 3.4 Post-Build: Using Your Custom Zig
*   Installed to: `~/.local/zig-0.15.0-dev.669+561ab59ce/`
*   Symlink: `~/.local/bin/zig-0.15.0-dev.669+561ab59ce`
*   Run with: `zig-0.15.0-dev.669+561ab59ce version`
*   To make it the default `zig` command: `ln -sf ~/.local/zig-0.15.0-dev.669+561ab59ce/bin/zig ~/.local/bin/zig`

---

## Part 4: System and Package Updates with Flakes 🔄
Updates are explicit and controlled with Flakes.

### 4.1 Understanding `flake.lock`
Your `flake.lock` (e.g., in `~/Utveckling/nixos-config/flake.lock`) pins the exact commits of your inputs (`nixpkgs`, `home-manager`). `nixos-rebuild` always uses these locked versions.

### 4.2 Minor Updates (Patches for NixOS 25.05)
1.  **Update Lock File:** Fetches latest commits on the `nixos-25.05` (and `release-25.05` for HM) branches.
    ```bash
    cd ~/Utveckling/nixos-config # Your Flake directory
    sudo nix flake update
    ```
2.  **Rebuild System:** Applies these newer packages.
    ```bash
    sudo nixos-rebuild switch --flake .#nixos # Or your system name
    ```

### 4.3 Major Upgrades (e.g., to a future NixOS 25.11)
1.  **Read Release Notes!** This is crucial for any breaking changes.
2.  **Edit `flake.nix`:** Update `inputs` URLs to point to the new release branches (e.g., `nixos-25.11`, `release-25.11`).
3.  **Update Lock File:** `sudo nix flake update`
4.  **First Rebuild:** `sudo nixos-rebuild switch --flake .#nixos`
5.  **Update `stateVersion`:** In `configuration.nix` and `users/blfnix.nix` to the new version string (e.g., `"25.11"`).
6.  **Second Rebuild:** `sudo nixos-rebuild switch --flake .#nixos`
7.  **Test thoroughly.**

### 4.4 Managing Other Flake Inputs
If you add more Flake inputs, update them with `sudo nix flake update <input-name>` or `sudo nix flake update` for all.

---

## Conclusion 🎉
You've now configured a NixOS system that is fully managed by Flakes, with your user environment declaratively controlled by Home Manager. This setup offers exceptional reproducibility and control.

**Key Takeaways:**
*   **Declarative Power:** System & user environments are defined as code.
*   **Reproducibility:** Flakes and `flake.lock` ensure consistent builds.
*   **Home Manager:** Provides clean, modular user environment management.
*   **Controlled Updates:** You have explicit control over system and package versions.
*   **Isolated Custom Builds:** `nix-shell` facilitates complex tasks like compiling Zig in a compatible environment.

This foundation empowers you to further refine and manage your NixOS system with confidence. Happy Nixin'!
