#!/bin/bash
# LazyVim Offline Wrapper - Installer
# Run this script from inside the extracted lazyvim-offline directory

set -e

# Handle being run from inside lazyvim-offline/ or from parent directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [ -d "$SCRIPT_DIR/lazy-plugins" ]; then
    # Running from inside lazyvim-offline/
    OFFLINE_DIR="$SCRIPT_DIR"
else
    # Running from parent directory
    OFFLINE_DIR="$SCRIPT_DIR/lazyvim-offline"

    # Extract if needed
    if [ ! -d "$OFFLINE_DIR" ]; then
        if [ -f "$SCRIPT_DIR/lazyvim-offline.tar.gz" ]; then
            echo "Extracting package..."
            tar -xzf "$SCRIPT_DIR/lazyvim-offline.tar.gz" -C "$SCRIPT_DIR"
        else
            echo "Error: lazyvim-offline.tar.gz not found"
            exit 1
        fi
    fi
fi

# Installation paths
LOCAL_BIN="${HOME}/.local/bin"
NVIM_CONFIG="${XDG_CONFIG_HOME:-$HOME/.config}/nvim"
NVIM_DATA="${XDG_DATA_HOME:-$HOME/.local/share}/nvim"
NVIM_STATE="${XDG_STATE_HOME:-$HOME/.local/state}/nvim"
NVIM_CACHE="${XDG_CACHE_HOME:-$HOME/.cache}/nvim"
# Runtime files go to a separate directory to avoid conflict with lazy.nvim data
NVIM_RUNTIME="${HOME}/.local/share/nvim-runtime"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}=== LazyVim Offline Installer ===${NC}"
echo ""

# Detect architecture
ARCH=$(uname -m)
if [ "$ARCH" != "x86_64" ]; then
    echo -e "${YELLOW}Warning: This package was built for x86_64, detected: $ARCH${NC}"
    echo "Neovim binary may not work on this architecture."
    read -p "Continue anyway? (y/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

# ============================================
# 1. Install Neovim binary
# ============================================
echo ""
echo -e "${YELLOW}[1/4] Installing Neovim...${NC}"

NVIM_SOURCE="$OFFLINE_DIR/nvim/linux-x64"

if [ ! -d "$NVIM_SOURCE" ]; then
    echo -e "${RED}Error: Neovim binaries not found in package${NC}"
    exit 1
fi

# Create ~/.local/bin if it doesn't exist
mkdir -p "$LOCAL_BIN"

# Copy neovim binary (rename to nvim.bin, create wrapper that sets VIMRUNTIME)
if [ -f "$NVIM_SOURCE/bin/nvim" ]; then
    cp "$NVIM_SOURCE/bin/nvim" "$LOCAL_BIN/nvim.bin"
    chmod +x "$LOCAL_BIN/nvim.bin"

    # Create wrapper script that sets VIMRUNTIME before launching nvim
    cat > "$LOCAL_BIN/nvim" << WRAPPER
#!/bin/bash
export VIMRUNTIME="\$HOME/.local/share/nvim-runtime/runtime"
exec "\$HOME/.local/bin/nvim.bin" "\$@"
WRAPPER
    chmod +x "$LOCAL_BIN/nvim"
    echo "  Neovim installed to $LOCAL_BIN/nvim (with runtime wrapper)"
else
    echo -e "${RED}Error: nvim binary not found${NC}"
    exit 1
fi

# Check if ~/.local/bin is in PATH
if [[ ":$PATH:" != *":$LOCAL_BIN:"* ]]; then
    echo ""
    echo -e "${YELLOW}Warning: $LOCAL_BIN is not in your PATH${NC}"
    echo "Add the following to your shell profile (~/.bashrc or ~/.zshrc):"
    echo "  export PATH=\"\$HOME/.local/bin:\$PATH\""
    echo ""
fi

# Copy neovim runtime files (separate from data dir to avoid conflict with lazy.nvim)
if [ -d "$NVIM_SOURCE/share/nvim" ]; then
    mkdir -p "$NVIM_RUNTIME"
    # Remove old runtime dir if present (fresh install)
    rm -rf "$NVIM_RUNTIME/runtime"
    cp -r "$NVIM_SOURCE/share/nvim" "$NVIM_RUNTIME/"
    echo "  Neovim runtime files installed to $NVIM_RUNTIME"
fi

# Copy neovim lib files if present
if [ -d "$NVIM_SOURCE/lib/nvim" ]; then
    mkdir -p "${HOME}/.local/lib"
    cp -r "$NVIM_SOURCE/lib/nvim" "${HOME}/.local/lib/"
fi

# Test the installed neovim
export PATH="$LOCAL_BIN:$PATH"
if command -v nvim &> /dev/null; then
    echo -e "${GREEN}  Neovim installed: $(nvim --version | head -1)${NC}"
else
    echo -e "${RED}  Warning: nvim command not available in PATH${NC}"
fi

# ============================================
# 2. Backup existing config
# ============================================
echo ""
echo -e "${YELLOW}[2/4] Backing up existing configuration...${NC}"

if [ -d "$NVIM_CONFIG" ]; then
    BACKUP="${NVIM_CONFIG}.bak.$(date +%Y%m%d%H%M%S)"
    echo "  Backing up $NVIM_CONFIG -> $BACKUP"
    mv "$NVIM_CONFIG" "$BACKUP"
fi

if [ -d "$NVIM_DATA" ]; then
    BACKUP="${NVIM_DATA}.bak.$(date +%Y%m%d%H%M%S)"
    echo "  Backing up $NVIM_DATA -> $BACKUP"
    mv "$NVIM_DATA" "$BACKUP"
fi

# ============================================
# 3. Install LazyVim configuration
# ============================================
echo ""
echo -e "${YELLOW}[3/4] Installing LazyVim configuration...${NC}"

mkdir -p "$NVIM_CONFIG"

# Copy starter config
cp -r "$OFFLINE_DIR/lazyvim-starter/"* "$NVIM_CONFIG/"
echo "  LazyVim starter config installed"

# Create offline-optimized init.lua
cat > "$NVIM_CONFIG/init.lua" << 'EOF'
-- LazyVim Offline Configuration
-- Automatically configured for offline mode

local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"

-- Check for lazy.nvim, install from local copy if missing
if not vim.loop.fs_stat(lazypath) then
    -- Fallback: should already be installed by install.sh
    vim.notify("lazy.nvim not found at " .. lazypath, vim.log.levels.ERROR)
    return
end
vim.opt.rtp:prepend(lazypath)

-- Setup plugins in offline mode
require("lazy").setup({
    spec = {
        { "LazyVim/LazyVim", import = "lazyvim.plugins" },
        { import = "plugins" },
    },
    defaults = {
        lazy = false,
        version = false,
    },
    -- CRITICAL: Disable all network operations
    install = {
        missing = false,  -- DO NOT try to install missing plugins
        colorscheme = { "tokyonight" },
    },
    checker = { enabled = false },  -- Disable update checking
    change_detection = { enabled = false },
    -- Use our pre-installed plugins
    performance = {
        rtp = {
            disabled_plugins = {
                "gzip",
                "matchit",
                "matchparen",
                "netrwPlugin",
                "tarPlugin",
                "tohtml",
                "tutor",
                "zipPlugin",
            },
        },
    },
})

-- Load user configuration
require("config.options")
require("config.keymaps")
require("config.autocmds")
EOF

echo "  Offline init.lua configured"

# ============================================
# 4. Install plugins (copy from offline package)
# ============================================
echo ""
echo -e "${YELLOW}[4/4] Installing plugins...${NC}"

mkdir -p "$NVIM_DATA/lazy"

PLUGIN_COUNT=0
for plugin_dir in "$OFFLINE_DIR/lazy-plugins"/*/; do
    if [ -d "$plugin_dir" ]; then
        plugin_name=$(basename "$plugin_dir")
        cp -r "$plugin_dir" "$NVIM_DATA/lazy/"
        PLUGIN_COUNT=$((PLUGIN_COUNT + 1))
    fi
done

echo "  $PLUGIN_COUNT plugins installed"

# Install Treesitter parsers
if [ -d "$OFFLINE_DIR/treesitter/linux-x64" ]; then
    PARSER_DST="$NVIM_DATA/lazy/nvim-treesitter/parser"
    mkdir -p "$PARSER_DST"
    COUNT=$(ls -1 "$OFFLINE_DIR/treesitter/linux-x64"/*.so 2>/dev/null | wc -l)
    if [ "$COUNT" -gt 0 ]; then
        cp "$OFFLINE_DIR/treesitter/linux-x64"/*.so "$PARSER_DST/"
        echo "  $COUNT Treesitter parsers installed"
    fi
else
    echo "  (No Treesitter parsers in package)"
fi

# Install Mason LSP
if [ -d "$OFFLINE_DIR/mason" ]; then
    cp -r "$OFFLINE_DIR/mason" "$NVIM_DATA/"
    echo "  Mason LSP servers installed"
else
    echo "  (No Mason LSP servers in package)"
fi

# ============================================
# Summary
# ============================================
echo ""
echo -e "${GREEN}============================================${NC}"
echo -e "${GREEN}Installation complete!${NC}"
echo ""
echo "  Neovim binary: $LOCAL_BIN/nvim (wrapper) -> $LOCAL_BIN/nvim.bin"
echo "  Runtime: $NVIM_RUNTIME/runtime"
echo "  Config: $NVIM_CONFIG"
echo "  Data: $NVIM_DATA"
echo ""
echo "  Plugins installed: $PLUGIN_COUNT"
if [ -d "$OFFLINE_DIR/treesitter" ]; then
    echo "  Treesitter: $COUNT parsers"
fi
if [ -d "$OFFLINE_DIR/mason" ]; then
    echo "  Mason: installed"
fi
echo ""

# Check PATH
if [[ ":$PATH:" != *":$LOCAL_BIN:"* ]]; then
    echo -e "${YELLOW}IMPORTANT: Add to your shell profile:${NC}"
    echo "  export PATH=\"\$HOME/.local/bin:\$PATH\""
    echo ""
fi

echo "Start LazyVim with:"
echo "  nvim"
echo ""
echo -e "${GREEN}============================================${NC}"

# Post-install message
echo ""
echo "Note: First start may take a moment as LazyVim initializes."
echo "All plugins are pre-installed, no network access required."
