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
    swayimg # For the 'imgdir' alias
  ];

  # --- ZSH CONFIGURATION ---
  programs.zsh = {
    enable = true;
    autosuggestion.enable = true;
    syntaxHighlighting.enable = true;
    
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
      # Enable Vi Keybindings (This is a fallback if keyMap = "vi" is not working as expected,
      # but keyMap = "vi" is the preferred declarative way. If keyMap works, this line can be removed.)
      bindkey -v

      # --- PATH Exports ---
      export PATH="$HOME/.cargo/bin:$PATH"
      export PATH="$HOME/.local/bin:$PATH"
      export PATH="$HOME/.npm-global/bin:$PATH"

      # FZF Environment Variables are now primarily managed by programs.fzf module
      # Keep KEYTIMEOUT here if it's mainly for ZLE/Vi mode responsiveness
      export KEYTIMEOUT=150

      # History search keybindings (these are standard Zsh and should work with fzf integration too)
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

      # Example venv functions (uncomment and adapt paths as needed)
      # v_mlmenv() { _activate_venv "mlmenv" "$HOME/.venv/mlmenv/bin/activate"; }
      # v_crawl4ai() { _activate_venv "crawl4ai" "$HOME/.venv/crawl4ai/bin/activate"; }
    '';
  };

  # --- PROGRAM CONFIGURATIONS ---
  programs.starship.enable = true;
  programs.zathura.enable = true;
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
    enable = true; # This installs fzf and enables basic shell integration
    enableZshIntegration = true; # Ensures Zsh specific keybindings (Ctrl-T, Ctrl-R, Alt-C) are set up

    # Sets FZF_DEFAULT_COMMAND. `fd` needs to be in `home.packages`.
    defaultCommand = "fd --type f --hidden --follow --exclude .git";

    # Sets FZF_DEFAULT_OPTS. Options are a list of strings.
    defaultOptions = [
      "--height 40%"
      "--layout=reverse"
      "--border"
      # The prompt needs to be a single string argument if it contains spaces.
      # If '➜  ' causes issues, try without the space or use simpler characters.
      "--prompt='➜  '"
      # Example of other options:
      # "--color=dark"
      # "--info=inline"
    ];
    # The `programs.fzf` module automatically handles setting up Ctrl-T, Ctrl-R, and Alt-C.
    # Ctrl-T will use `defaultCommand`.
    # Alt-C typically uses `fd --type d` or `find . -type d` by default through the integration.
    # If you need to override Alt-C specifically, you might still need FZF_ALT_C_COMMAND
    # in home.sessionVariables if the module doesn't directly control it.
  };

  # --- GLOBAL ENVIRONMENT VARIABLES ---
  home.sessionVariables = {
    EDITOR = "hx";
    VISUAL = "hx";
    PAGER = "less";
    CC = "clang";
    CXX = "clang++";
    GIT_TERMINAL_PROMPT = "1";

    # This ensures Alt-C uses your preferred 'fd' command for directory searching with fzf.
    # The fzf shell integration scripts will pick this up.
    FZF_ALT_C_COMMAND = "fd --type d --hidden --follow --exclude .git";
  };
}
