#!/bin/bash
# NvChad Offline Installation Script
# Run this script from inside the extracted nvchad-offline directory

set -e

# Handle being run from inside nvchad-offline/ or from parent directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [ -d "$SCRIPT_DIR/lazy-plugins" ]; then
    # Running from inside nvchad-offline/
    OFFLINE_DIR="$SCRIPT_DIR"
else
    # Running from parent directory
    OFFLINE_DIR="$SCRIPT_DIR/nvchad-offline"

    # Extract if needed
    if [ ! -d "$OFFLINE_DIR" ]; then
        if [ -f "$SCRIPT_DIR/nvchad-offline.tar.gz" ]; then
            echo "Extracting package..."
            tar -xzf "$SCRIPT_DIR/nvchad-offline.tar.gz" -C "$SCRIPT_DIR"
        else
            echo "Error: nvchad-offline.tar.gz not found"
            exit 1
        fi
    fi
fi

NVIM_CONFIG="${XDG_CONFIG_HOME:-$HOME/.config}/nvim"
NVIM_DATA="${XDG_DATA_HOME:-$HOME/.local/share}/nvim"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}=== NvChad Offline Installer ===${NC}"
echo ""

# Check Neovim
if ! command -v nvim &> /dev/null; then
    echo -e "${RED}Error: Neovim not found${NC}"
    echo "Install Neovim >= 0.11 first"
    exit 1
fi

echo -e "${GREEN}Found: $(nvim --version | head -1)${NC}"

# Backup existing config
if [ -d "$NVIM_CONFIG" ]; then
    BACKUP="${NVIM_CONFIG}.bak.$(date +%Y%m%d%H%M%S)"
    echo "Backing up $NVIM_CONFIG -> $BACKUP"
    mv "$NVIM_CONFIG" "$BACKUP"
fi

# Backup existing data
if [ -d "$NVIM_DATA/lazy" ] || [ -d "$NVIM_DATA/mason" ]; then
    BACKUP="${NVIM_DATA}.bak.$(date +%Y%m%d%H%M%S)"
    mkdir -p "$BACKUP"
    [ -d "$NVIM_DATA/lazy" ] && mv "$NVIM_DATA/lazy" "$BACKUP/"
    [ -d "$NVIM_DATA/mason" ] && mv "$NVIM_DATA/mason" "$BACKUP/"
    [ -d "$NVIM_DATA/base46" ] && mv "$NVIM_DATA/base46" "$BACKUP/"
fi

# Install config
echo ""
echo "Installing config..."
mkdir -p "$NVIM_CONFIG" "$NVIM_DATA/lazy" "$NVIM_DATA/lazy-dev" "$NVIM_DATA/base46"
cp -r "$OFFLINE_DIR/starter/"* "$NVIM_CONFIG/"

# Create offline init.lua
cat > "$NVIM_CONFIG/init.lua" << 'EOF'
vim.g.base46_cache = vim.fn.stdpath "data" .. "/base46/"
vim.g.mapleader = " "

local lazypath = vim.fn.stdpath "data" .. "/lazy/lazy.nvim"
vim.opt.rtp:prepend(lazypath)

if not vim.loop.fs_stat(lazypath) then
    vim.notify("lazy.nvim not found", vim.log.levels.ERROR)
    return
end

local lazy_config = require "configs.lazy"
lazy_config.install = { missing = false, colorscheme = { "nvchad" } }
lazy_config.checker = { enabled = false }
lazy_config.change_detection = { enabled = false }

require("lazy").setup({
    { "NvChad/NvChad", lazy = false, dir = vim.fn.stdpath("data") .. "/lazy-dev/NvChad", import = "nvchad.plugins" },
    { import = "plugins" },
}, lazy_config)

local cache = vim.g.base46_cache
if vim.loop.fs_stat(cache .. "defaults") then
    dofile(cache .. "defaults")
    dofile(cache .. "statusline")
end

require "options"
require "autocmds"
vim.schedule(function() require "mappings" end)
EOF

# Install plugins
echo "Installing plugins..."
cp -r "$OFFLINE_DIR/lazy-plugins/lazy.nvim" "$NVIM_DATA/lazy/"
cp -r "$OFFLINE_DIR/base-config/NvChad" "$NVIM_DATA/lazy-dev/"

PLUGIN_COUNT=0
for d in "$OFFLINE_DIR/lazy-plugins"/*/; do
    name=$(basename "$d")
    [ "$name" != "lazy.nvim" ] && cp -r "$d" "$NVIM_DATA/lazy/" && PLUGIN_COUNT=$((PLUGIN_COUNT + 1))
done
echo "  $PLUGIN_COUNT plugins installed"

# Install Treesitter parsers
echo ""
if [ -d "$OFFLINE_DIR/treesitter/linux-x64" ]; then
    PARSER_DST="$NVIM_DATA/lazy/nvim-treesitter/parser"
    mkdir -p "$PARSER_DST"
    COUNT=$(ls -1 "$OFFLINE_DIR/treesitter/linux-x64"/*.so 2>/dev/null | wc -l)
    if [ "$COUNT" -gt 0 ]; then
        cp "$OFFLINE_DIR/treesitter/linux-x64"/*.so "$PARSER_DST/"
        echo -e "${GREEN}$COUNT Treesitter parsers installed${NC}"
    fi
else
    echo -e "${YELLOW}No Treesitter parsers found (syntax highlighting may be limited)${NC}"
fi

# Install Mason LSP
echo ""
if [ -d "$OFFLINE_DIR/mason" ]; then
    cp -r "$OFFLINE_DIR/mason" "$NVIM_DATA/"
    echo -e "${GREEN}Mason LSP servers installed${NC}"
else
    echo -e "${YELLOW}No Mason LSP servers found${NC}"
fi

# Generate cache
echo ""
echo "Generating theme cache..."
nvim --headless "+q!" 2>/dev/null || true

echo ""
echo -e "${GREEN}============================================${NC}"
echo -e "${GREEN}Installation complete!${NC}"
echo ""
echo "Run: nvim"
echo -e "${GREEN}============================================${NC}"
