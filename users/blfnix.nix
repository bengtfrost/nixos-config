
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
    rustup
    python313
    uv
    nodejs_24
    zig
    zls

    # BUILD TOOLS for custom Zig dev build (and general use)
    cmake
    ninja # Ninja build system

    # LLVM/Clang Toolchain (LLVM 20 - or your chosen version)
    llvmPackages_20.clang       # Provides clang, clang++, and standard wrappers
    llvmPackages_20.llvm        # Core LLVM tools and libraries (llvm-config, etc.)
    llvmPackages_20.lld         # The LLVM linker, lld
    # llvmPackages_20.bintools  # Intentionally removed to solve objdump collision
    llvmPackages_20.clang-tools # Provides clangd, clang-format, clang-tidy

    # Editors & LSPs
    helix
    marksman
    # You could add rust-analyzer, nil, clangd (from clang-tools) etc. here for Helix

    # CLI Tools & Utilities
    tmux
    pass
    keychain
    git
    gh
    fd           # fzf will use this via FZF_DEFAULT_COMMAND
    ripgrep
    bat
    jq
    # fzf is now managed by programs.fzf module below
    xclip
    yazi
    ueberzugpp
    unar
    ffmpegthumbnailer
    poppler_utils
    w3m
    zathura 
    zsh-autocomplete
  ];

  # --- ZSH CONFIGURATION ---
  programs.zsh = {
    enable = true;
    autosuggestion.enable = true;     # For zsh-autosuggestions plugin
    syntaxHighlighting.enable = true; # For zsh-syntax-highlighting plugin
    # keyMap = "vi";                    # Enable Vi keybindings

    # --- ZSH PLUGINS ---
    # Home Manager will handle installing and sourcing these plugins.
    # plugins = [
      # {
        # name = "zsh-autocomplete"; # Identifier for Home Manager
        # src = pkgs.zsh-autocomplete; # The Nix package for the plugin
      # }
      # Add other plugins here if needed, e.g.:
      # { name = "zsh-history-substring-search"; src = pkgs.zsh-history-substring-search; }
    # ];

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
      path = "${config.xdg.dataHome}/zsh/history"; # Keeps history in ~/.local/share
      share = true;              # Share history between all sessions
      ignoreDups = true;         # Don't record an entry if it's the same as the previous one
      ignoreSpace = true;        # Commands starting with a space are not saved
      save = 10000;
    };

    initContent = ''
      # Fallback for Vi Keybindings if keyMap = "vi" option doesn't work as expected
      bindkey -v

      # --- PATH Exports ---
      export PATH="$HOME/.cargo/bin:$PATH"
      export PATH="$HOME/.local/bin:$PATH"
      export PATH="$HOME/.npm-global/bin:$PATH"

      # KEYTIMEOUT for ZLE responsiveness, especially in Vi mode
      export KEYTIMEOUT=150

      # History search keybindings (standard Zsh, compatible with plugins)
      autoload -Uz up-line-or-beginning-search down-line-or-beginning-search
      zle -N up-line-or-beginning-search
      zle -N down-line-or-beginning-search
      bindkey "^[[A" up-line-or-beginning-search   # Arrow Up
      bindkey "^[[B" down-line-or-beginning-search # Arrow Down

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

      # Example venv functions 
      v_mlmenv() { _activate_venv "mlmenv" "$HOME/.venv/mlmenv/bin/activate"; }
      v_crawl4ai() { _activate_venv "crawl4ai" "$HOME/.venv/crawl4ai/bin/activate"; }
    '';
  };

  # --- PROGRAM CONFIGURATIONS ---
  programs.starship.enable = true;
  programs.helix.enable = true;

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

    # Sets FZF_DEFAULT_COMMAND. `fd` (from home.packages) will be used.
    defaultCommand = "fd --type f --hidden --follow --exclude .git";

    # Sets FZF_DEFAULT_OPTS.
    defaultOptions = [
      "--height 40%"
      "--layout=reverse"
      "--border"
      "--prompt='➜  '" # The prompt string for fzf
    ];
  };

  programs.zathura = {
    enable = true;
    # Add your zathurarc settings here
    options = {
      # These will be written to the generated zathurarc
      selection-clipboard = "clipboard";
      adjust-open = "best-fit";
      # Add any other zathurarc settings you want
      # For example:
      # "font" = "Monospace 12";
      # "default-bg" = "#282a36";
      # "statusbar-fg" = "#f8f8f2";
      # "statusbar-bg" = "#44475a";
      default-bg =                 "#212121";
      default-fg =                 "#303030";
      statusbar-fg =               "#B2CCD6";
      statusbar-bg =               "#353535";
      inputbar-bg =                "#212121";
      inputbar-fg =                "#FFFFFF";
      notification-bg =            "#212121";
      notification-fg =            "#FFFFFF";
      notification-error-bg =      "#212121";
      notification-error-fg =      "#F07178";
      notification-warning-bg =    "#212121";
      notification-warning-fg =    "#F07178";
      highlight-color =            "#FFCB6B";
      highlight-active-color =     "#82AAFF";
      completion-bg =              "#303030";
      completion-fg =              "#82AAFF";
      completion-highlight-fg =    "#FFFFFF";
      completion-highlight-bg =    "#82AAFF";
      recolor-lightcolor =         "#212121";
      recolor-darkcolor =          "#EEFFFF";
      recolor =                    "false";
      recolor-keephue =            "false";
    };
    # If you have many settings or prefer a separate file:
    # extraConfig = ''
    #   set selection-clipboard clipboard
    #   set adjust-open best-fit
    #   # More settings
    # '';
    # Or even source an entire file you manage within your flake:
    # extraConfig = builtins.readFile ../dotfiles/zathurarc-custom; # Assuming path in your flake
  };

  # --- GLOBAL ENVIRONMENT VARIABLES ---
  home.sessionVariables = {
    EDITOR = "hx";
    VISUAL = "hx";
    PAGER = "less";
    CC = "clang";
    CXX = "clang++";
    GIT_TERMINAL_PROMPT = "1";

    # Ensures fzf's Alt-C (change directory) binding uses `fd` for directory listing.
    FZF_ALT_C_COMMAND = "fd --type d --hidden --follow --exclude .git";
  };
}
