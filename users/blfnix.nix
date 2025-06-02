# /etc/nixos/users/blfnix.nix
{ pkgs, config, lib, inputs, ... }:

{
  home.username = "blfnix";
  home.homeDirectory = "/home/blfnix";
  home.stateVersion = "25.05";

  # --- PACKAGES ---
  # All your user-specific packages are managed here.
  home.packages = with pkgs; [
    # Dev Toolchains
    rustup # For rustc, cargo, rust-analyzer, rustfmt (via rustup component add)
    python313 # For Python development
    uv        # For project-local Python venvs (use with Nix-provided Python)
    nodejs_24 # Provides node, npm (for LSPs below if they are node-based)
    zig       # System's stable Zig (e.g., 0.14)
    zls       # Language server for system's stable Zig
    zsh-autocomplete # For Zsh autocompletion

    # BUILD TOOLS for custom Zig dev build (and general use)
    cmake
    ninja # Ninja build system

    # LLVM/Clang Toolchain (LLVM 20 - or your chosen version)
    llvmPackages_20.clang       # Provides clang, clang++, and standard wrappers
    llvmPackages_20.llvm        # Core LLVM tools and libraries (llvm-config, etc.)
    llvmPackages_20.lld         # The LLVM linker, lld
    # llvmPackages_20.bintools  # Intentionally not included to avoid objdump collision if clang handles it
    llvmPackages_20.clang-tools # Provides clangd, clang-format

    # Editors
    helix

    # === LSPs and FORMATTERS for HELIX (from Nixpkgs) ===
    marksman     # Markdown LSP

    # Python LSPs & Formatters
    ruff         # Provides 'ruff server' (LSP) and 'ruff format' / 'ruff check --fix'
    python313Packages.python-lsp-server # Provides 'pylsp' command

    # TypeScript/JavaScript/JSON/YAML - LSPs
    nodePackages.typescript-language-server # Provides 'typescript-language-server'
    nodePackages.vscode-json-languageserver # Provides 'json-language-server' (for JSON)
    nodePackages.yaml-language-server       # Provides 'yaml-language-server'

    # Formatters
    dprint       # General purpose formatter, command 'dprint'
    taplo        # TOML formatter and LSP provider, command 'taplo' (includes 'taplo lsp stdio')
    # Note: clang-format is from llvmPackages_20.clang-tools
    # Note: rustfmt is installed via `rustup component add rustfmt`
    # Note: zig fmt is part of the `zig` executable

    # === END LSPs and FORMATTERS ===

    # CLI Tools & Utilities
    tmux
    pass
    keychain
    git          # Standard git package
    gh           # GitHub CLI
    fd           # For fzf and general use
    ripgrep
    bat
    jq
    # fzf is managed by programs.fzf module below
    xclip
    yazi
    ueberzugpp   # For yazi image previews
    unar         # For yazi archive previews
    ffmpegthumbnailer # For yazi video thumbnails
    poppler_utils     # For yazi PDF previews
    w3m          # Text-based browser
    zathura      # Document viewer
  ];

  # --- ZSH CONFIGURATION ---
  programs.zsh = {
    enable = true;
    autosuggestion.enable = true;
    syntaxHighlighting.enable = true;
    # keyMap = "vi"; # Using bindkey -v in initContent for reliability

    shellAliases = {
      ls = "ls --color=auto -F";
      ll = "ls -alhF";
      la = "ls -AF";
      l  = "ls -CF";
      glog = "git log --oneline --graph --decorate --all";
      cc = "clang"; # Will use clang from llvmPackages_20
      cxx = "clang++"; # Will use clang++ from llvmPackages_20
    };

    history = {
      size = 10000;
      path = "${config.xdg.dataHome}/zsh/history";
      share = true;
      ignoreDups = true;
      ignoreSpace = true;
      save = 10000;
    };

    initContent = ''
      # Enable Vi Keybindings
      bindkey -v

      # --- PATH Exports ---
      # These ensure tools installed outside of Nix (but within user's home) are found.
      # Nix-managed tools (from home.packages) are typically prepended to PATH by Home Manager.
      export PATH="$HOME/.cargo/bin:$PATH"   # For rustup tools (rustc, cargo, rust-analyzer, rustfmt) & cargo install
      export PATH="$HOME/.local/bin:$PATH" # For user scripts & custom builds (like your Zig dev)
      export PATH="$HOME/.npm-global/bin:$PATH" # For any global npm packages not managed by Nix

      # KEYTIMEOUT for ZLE responsiveness, especially in Vi mode
      export KEYTIMEOUT=150

      # History search keybindings - COMMENTED OUT to allow zsh-autocomplete to use arrow keys
      # autoload -Uz up-line-or-beginning-search down-line-or-beginning-search
      # zle -N up-line-or-beginning-search
      # zle -N down-line-or-beginning-search
      # bindkey "^[[A" up-line-or-beginning-search
      # bindkey "^[[B" down-line-or-beginning-search

      # --- Custom Functions ---
      multipull() {
        local BASE_DIR=~/.code
        if [[ ! -d "$BASE_DIR" ]]; then
          echo "multipull: Base directory not found: $BASE_DIR" >&2
          return 1
        fi
        echo "Searching for Git repositories under $BASE_DIR..."
        fd --hidden --no-ignore --type d '^\.git$' "$BASE_DIR" | while read -r gitdir; do
          local workdir=$(dirname "$gitdir")
          echo -e "\n=== Updating $workdir ==="
          if (cd "$workdir" && git rev-parse --abbrev-ref --symbolic-full-name '@{u}' &>/dev/null); then
            git -C "$workdir" pull
          else
            local branch=$(git -C "$workdir" rev-parse --abbrev-ref HEAD)
            echo "--- Skipping pull (no upstream configured for branch: $branch) ---"
          fi
        done
        echo -e "\nMultipull finished."
      }

      _activate_venv() {
        local venv_name="$1"
        local venv_activate_path="$2"
        if [[ ! -f "$venv_activate_path" ]]; then
          echo "Error: Activation script not found: $venv_activate_path" >&2; return 1
        fi
        # Deactivate if another venv is active
        [[ "$(type -t deactivate)" = "function" ]] && deactivate
        . "$venv_activate_path" && echo "Activated venv: $venv_name"
      }

      # Example venv functions (uncomment and adapt paths as needed)
      v_mlmenv() { _activate_venv "mlmenv" "$HOME/.venv/python3.13/mlmenv/bin/activate"; }
      v_crawl4ai() { _activate_venv "crawl4ai" "$HOME/.venv/python3.13/crawl4ai/bin/activate"; }
    '';
  };

  # --- PROGRAM CONFIGURATIONS ---
  programs.starship.enable = true;
  programs.helix.enable = true; # Ensures Helix editor itself is from Nixpkgs

  programs.git = {
    enable = true;
    userName = "Bengt Frost";
    userEmail = "bengtfrost@gmail.com";
    extraConfig = {
      core.editor = "hx";
      init.defaultBranch = "main";
    };
  };

  programs.fzf = {
    enable = true; # Installs fzf and enables basic shell integration
    enableZshIntegration = true; # Sets up Zsh keybindings (Ctrl-T, Ctrl-R, Alt-C)
    defaultCommand = "fd --type f --hidden --follow --exclude .git";
    defaultOptions = [
      "--height 40%"
      "--layout=reverse"
      "--border"
      "--prompt='➜  '"
    ];
  };

  programs.zathura = {
    enable = true;
    options = {
      selection-clipboard = "clipboard";
      adjust-open = "best-fit";
      default-bg = "#212121";
      default-fg = "#303030";
      statusbar-fg = "#B2CCD6";
      statusbar-bg = "#353535";
      inputbar-bg = "#212121";
      inputbar-fg = "#FFFFFF";
      notification-bg = "#212121";
      notification-fg = "#FFFFFF";
      notification-error-bg = "#212121";
      notification-error-fg = "#F07178";
      notification-warning-bg = "#212121";
      notification-warning-fg = "#F07178";
      highlight-color = "#FFCB6B";
      highlight-active-color = "#82AAFF";
      completion-bg = "#303030";
      completion-fg = "#82AAFF";
      completion-highlight-fg = "#FFFFFF";
      completion-highlight-bg = "#82AAFF";
      recolor-lightcolor = "#212121";
      recolor-darkcolor = "#EEFFFF";
      recolor = false; # Note: boolean, not string "false"
      recolor-keephue = false; # Note: boolean
    };
  };

  # --- MANAGING HELIX CONFIGURATION FILES (Recommended) ---
  # Assumes you have created these files inside your flake, e.g., at
  # /etc/nixos/dotfiles/helix/languages.toml
  # /etc/nixos/dotfiles/helix/config.toml (if you manage it too)
  # The path `../dotfiles/` is relative to this `blfnix.nix` file's location
  # (e.g. if blfnix.nix is in /etc/nixos/users/ and dotfiles/ is in /etc/nixos/dotfiles/)
  xdg.configFile."helix/languages.toml" = {
    source = ../dotfiles/helix/languages.toml;
    # If you don't want to manage it via a separate file and prefer inline text:
    # text = ''
    #   # Paste your languages.toml content here
    # '';
  };
  # Example for config.toml:
  # xdg.configFile."helix/config.toml" = {
  #   source = ../dotfiles/helix/config.toml;
  # };


  # --- GLOBAL ENVIRONMENT VARIABLES ---
  home.sessionVariables = {
    EDITOR = "hx";
    VISUAL = "hx";
    PAGER = "less";
    CC = "clang";
    CXX = "clang++";
    GIT_TERMINAL_PROMPT = "1";
    FZF_ALT_C_COMMAND = "fd --type d --hidden --follow --exclude .git";
  };
}
