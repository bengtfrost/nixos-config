# /etc/nixos/users/blfnix.nix
{ pkgs, config, lib, inputs, ... }:

{
  home.username = "blfnix";
  home.homeDirectory = "/home/blfnix";
  home.stateVersion = "25.05";

  home.packages = with pkgs; [
    rustup
    python313
    uv
    nodejs_24
    zig
    zls
    cmake
    ninja

    # LLVM/Clang Toolchain (LLVM 20)
    llvmPackages_20.clang       # Provides clang, clang++, and standard wrappers
    llvmPackages_20.llvm        # Core LLVM tools and libraries (llvm-config, etc.)
    llvmPackages_20.lld         # The LLVM linker, lld
    # llvmPackages_20.bintools  # TEMPORARILY COMMENTED OUT to resolve objdump collision
    llvmPackages_20.clang-tools # Provides clangd, clang-format, clang-tidy

    helix
    marksman
    tmux
    pass
    keychain
    git
    gh
    fd
    ripgrep
    bat
    jq
    fzf
    xclip
    yazi
    ueberzugpp
    unar
    ffmpegthumbnailer
    poppler_utils
    w3m
    zathura
    swayimg
  ];

  # --- ZSH CONFIGURATION ---
  programs.zsh = {
    enable = true;
    autosuggestion.enable = true;
    syntaxHighlighting.enable = true;
    # keyMap = "vi"; # Replaced by bindkey -v in initContent due to option changes

    shellAliases = { /* ... */ };
    history = { /* ... */ };
    initContent = ''
      bindkey -v # Enable Vi Keybindings

      # --- PATH Exports ---
      # ... (rest of initContent as before) ...
      export PATH="$HOME/.cargo/bin:$PATH"
      export PATH="$HOME/.local/bin:$PATH"
      export PATH="$HOME/.npm-global/bin:$PATH"
      export FZF_DEFAULT_COMMAND='fd --type f --hidden --follow --exclude .git'
      export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
      export FZF_ALT_C_COMMAND='fd --type d --hidden --follow --exclude .git'
      export FZF_DEFAULT_OPTS="--height 40% --layout=reverse --border --prompt='➜  '"
      export KEYTIMEOUT=150
      autoload -Uz up-line-or-beginning-search down-line-or-beginning-search
      zle -N up-line-or-beginning-search
      zle -N down-line-or-beginning-search
      bindkey "^[[A" up-line-or-beginning-search
      bindkey "^[[B" down-line-or-beginning-search
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
        [[ "$(type -t deactivate)" = "function" ]] && deactivate
        . "$venv_activate_path" && echo "Activated venv: $venv_name"
      }
      v_mlmenv() { _activate_venv "mlmenv" "$HOME/.venv/mlmenv/bin/activate"; }
      v_crawl4ai() { _activate_venv "crawl4ai" "$HOME/.venv/crawl4ai/bin/activate"; }
    '';
  };

  # --- PROGRAM CONFIGURATIONS ---
  programs.starship.enable = true;
  programs.zathura.enable = true;
  programs.helix.enable = true;
  programs.git = { /* ... */ };

  # --- GLOBAL ENVIRONMENT VARIABLES ---
  home.sessionVariables = { /* ... */ };
}
