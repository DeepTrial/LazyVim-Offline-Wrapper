#!/bin/bash
# NvChad Offline Package Builder
# Run this script in an online environment to create the offline package

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OFFLINE_DIR="${SCRIPT_DIR}/nvchad-offline"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Parse arguments
BUILD_TREESITTER=false
BUILD_MASON=false
PARSERS=""
LSP_SERVERS=""

usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  --treesitter [parsers]  Build Treesitter parsers (comma-separated)"
    echo "                          Default: lua,vim,vimdoc,python,javascript,typescript,json,html,css,bash"
    echo "  --mason [packages]      Build Mason LSP servers (comma-separated)"
    echo "                          Default: lua_ls"
    echo "  --all                   Build both Treesitter and Mason with defaults"
    echo "  --help                  Show this help"
    echo ""
    echo "Examples:"
    echo "  $0                                    # Download plugins only"
    echo "  $0 --treesitter                       # Download + build default parsers"
    echo "  $0 --treesitter lua,vim,python        # Download + build specific parsers"
    echo "  $0 --mason lua_ls,pylsp               # Download + build specific LSP"
    echo "  $0 --all                              # Download + build everything"
    exit 0
}

# Default parsers
DEFAULT_PARSERS="lua,vim,vimdoc,python,javascript,typescript,json,html,css,bash,c,cpp"
DEFAULT_LSP="lua_ls"

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --treesitter)
            BUILD_TREESITTER=true
            if [[ -n "$2" && ! "$2" =~ ^-- ]]; then
                PARSERS="$2"
                shift
            else
                PARSERS="$DEFAULT_PARSERS"
            fi
            shift
            ;;
        --mason)
            BUILD_MASON=true
            if [[ -n "$2" && ! "$2" =~ ^-- ]]; then
                LSP_SERVERS="$2"
                shift
            else
                LSP_SERVERS="$DEFAULT_LSP"
            fi
            shift
            ;;
        --all)
            BUILD_TREESITTER=true
            BUILD_MASON=true
            PARSERS="$DEFAULT_PARSERS"
            LSP_SERVERS="$DEFAULT_LSP"
            shift
            ;;
        --help|-h)
            usage
            ;;
        *)
            echo "Unknown option: $1"
            usage
            ;;
    esac
done

echo -e "${GREEN}=== NvChad Offline Package Builder ===${NC}"
echo ""

# Create directory structure
mkdir -p "$OFFLINE_DIR"/{lazy-plugins,starter,base-config}

# ============================================
# 1. Download lazy.nvim plugin manager
# ============================================
echo -e "${YELLOW}[1/4] Downloading lazy.nvim...${NC}"
git clone --depth 1 https://github.com/folke/lazy.nvim "$OFFLINE_DIR/lazy-plugins/lazy.nvim"
rm -rf "$OFFLINE_DIR/lazy-plugins/lazy.nvim/.git"

# ============================================
# 2. Download NvChad configs
# ============================================
echo -e "${YELLOW}[2/4] Downloading NvChad configs...${NC}"
git clone --depth 1 https://github.com/nvchad/starter "$OFFLINE_DIR/starter"
rm -rf "$OFFLINE_DIR/starter/.git"

git clone --depth 1 --branch v2.5 https://github.com/NvChad/NvChad "$OFFLINE_DIR/base-config/NvChad"
rm -rf "$OFFLINE_DIR/base-config/NvChad/.git"

# ============================================
# 3. Download plugins
# ============================================
echo -e "${YELLOW}[3/4] Downloading plugins...${NC}"

declare -A PLUGINS=(
    ["nvim-lua/plenary.nvim"]="plenary.nvim"
    ["NvChad/base46"]="base46"
    ["NvChad/ui"]="ui"
    ["nvzone/volt"]="volt"
    ["nvzone/menu"]="menu"
    ["nvzone/minty"]="minty"
    ["nvim-tree/nvim-web-devicons"]="nvim-web-devicons"
    ["lukas-reineke/indent-blankline.nvim"]="indent-blankline.nvim"
    ["nvim-tree/nvim-tree.lua"]="nvim-tree.lua"
    ["folke/which-key.nvim"]="which-key.nvim"
    ["stevearc/conform.nvim"]="conform.nvim"
    ["lewis6991/gitsigns.nvim"]="gitsigns.nvim"
    ["mason-org/mason.nvim"]="mason.nvim"
    ["neovim/nvim-lspconfig"]="nvim-lspconfig"
    ["hrsh7th/nvim-cmp"]="nvim-cmp"
    ["L3MON4D3/LuaSnip"]="LuaSnip"
    ["rafamadriz/friendly-snippets"]="friendly-snippets"
    ["windwp/nvim-autopairs"]="nvim-autopairs"
    ["saadparwaiz1/cmp_luasnip"]="cmp_luasnip"
    ["hrsh7th/cmp-nvim-lua"]="cmp-nvim-lua"
    ["hrsh7th/cmp-nvim-lsp"]="cmp-nvim-lsp"
    ["hrsh7th/cmp-buffer"]="cmp-buffer"
    ["nvim-telescope/telescope.nvim"]="telescope.nvim"
    ["nvim-treesitter/nvim-treesitter"]="nvim-treesitter"
)

for repo in "${!PLUGINS[@]}"; do
    dir="${PLUGINS[$repo]}"
    printf "  %-25s " "$dir"
    git clone --depth 1 "https://github.com/$repo" "$OFFLINE_DIR/lazy-plugins/$dir" 2>/dev/null
    rm -rf "$OFFLINE_DIR/lazy-plugins/$dir/.git"
    echo "OK"
done

# cmp-async-path from codeberg
printf "  %-25s " "cmp-async-path"
git clone --depth 1 https://codeberg.org/FelipeLema/cmp-async-path "$OFFLINE_DIR/lazy-plugins/cmp-async-path" 2>/dev/null
rm -rf "$OFFLINE_DIR/lazy-plugins/cmp-async-path/.git"
echo "OK"

# ============================================
# 4. Build Treesitter parsers
# ============================================
echo ""
echo -e "${YELLOW}[4/4] Building components...${NC}"

if [ "$BUILD_TREESITTER" = true ]; then
    echo ""
    echo -e "${GREEN}Building Treesitter parsers...${NC}"

    if ! command -v nvim &> /dev/null; then
        echo -e "${RED}Error: Neovim not found. Cannot build Treesitter parsers.${NC}"
        echo "Install Neovim or use GitHub Actions instead."
        exit 1
    fi

    PARSER_DIR="$OFFLINE_DIR/treesitter/linux-x64"
    mkdir -p "$PARSER_DIR"

    # Create a proper Neovim config directory structure
    BUILD_ROOT=$(mktemp -d)
    BUILD_CONFIG="$BUILD_ROOT/config/nvim"
    BUILD_DATA="$BUILD_ROOT/data"
    BUILD_STATE="$BUILD_ROOT/state"
    BUILD_CACHE="$BUILD_ROOT/cache"

    mkdir -p "$BUILD_CONFIG" "$BUILD_DATA/nvim/site/pack/dist/start" "$BUILD_STATE" "$BUILD_CACHE"

    # Copy treesitter plugin to pack directory (auto-loaded)
    # Must be in XDG_DATA_HOME/nvim/site/pack/ for Neovim to find it
    cp -r "$OFFLINE_DIR/lazy-plugins/nvim-treesitter" "$BUILD_DATA/nvim/site/pack/dist/start/"

    # Create init.lua with treesitter setup
    cat > "$BUILD_CONFIG/init.lua" << 'INITEOF'
-- Explicitly add treesitter plugin to runtimepath
local ts_dir = vim.env.TS_PLUGIN_DIR
if ts_dir and ts_dir ~= "" then
    vim.opt.rtp:prepend(ts_dir)
end

-- Parse the list of parsers to install
local parser_str = vim.env.PARSERS_TO_INSTALL or ""
local parsers = {}
for parser in string.gmatch(parser_str, "([^,]+)") do
    table.insert(parsers, vim.trim(parser))
end

-- Install after plugins are loaded
vim.api.nvim_create_autocmd("VimEnter", {
    once = true,
    callback = function()
        for _, parser in ipairs(parsers) do
            print("Installing: " .. parser)
            local ok, err = pcall(vim.cmd, "TSInstall " .. parser)
            if not ok then
                print("  Error starting: " .. tostring(err))
            end
        end

        -- Wait for async installs to complete, then quit
        -- TSInstall is async; 120s is enough for 12 parsers to download + compile
        vim.defer_fn(function()
            print("Install wait complete, exiting.")
            vim.cmd("q!")
        end, 120000)
    end,
})
INITEOF

    echo "  Installing parsers: ${PARSERS//,/, }"

    # Run Neovim with our config
    XDG_CONFIG_HOME="$BUILD_ROOT/config" \
    XDG_DATA_HOME="$BUILD_DATA" \
    XDG_STATE_HOME="$BUILD_STATE" \
    XDG_CACHE_HOME="$BUILD_CACHE" \
    PARSERS_TO_INSTALL="$PARSERS" \
    TS_PLUGIN_DIR="$BUILD_DATA/nvim/site/pack/dist/start/nvim-treesitter" \
    nvim --headless 2>&1 || true

    # Find compiled parsers anywhere under the build tree
    echo "  Searching for compiled parsers..."
    find "$BUILD_ROOT" -name "*.so" -type f | while read -r sofile; do
        echo "    Found: $sofile"
        cp "$sofile" "$PARSER_DIR/" 2>/dev/null || true
    done

    # Count final
    FINAL_COUNT=$(ls -1 "$PARSER_DIR"/*.so 2>/dev/null | wc -l)
    if [ "$FINAL_COUNT" -gt 0 ]; then
        echo -e "  ${GREEN}Built $FINAL_COUNT parsers${NC}"
        ls "$PARSER_DIR"/*.so | xargs -n1 basename
    else
        echo -e "  ${RED}Error: No parsers were built${NC}"
        echo "  Diagnostics - directory tree:"
        find "$BUILD_ROOT" -type d | head -30
        echo "  Check if gcc/g++ are installed"
    fi

    rm -rf "$BUILD_ROOT"
fi

# ============================================
# 5. Build Mason LSP servers
# ============================================

if [ "$BUILD_MASON" = true ]; then
    echo ""
    echo -e "${GREEN}Building Mason LSP servers...${NC}"

    if ! command -v nvim &> /dev/null; then
        echo -e "${RED}Error: Neovim not found. Cannot build Mason packages.${NC}"
        exit 1
    fi

    MASON_DIR="$OFFLINE_DIR/mason"
    mkdir -p "$MASON_DIR"

    # Create a proper Neovim config directory structure
    BUILD_ROOT=$(mktemp -d)
    BUILD_CONFIG="$BUILD_ROOT/config/nvim"
    BUILD_DATA="$BUILD_ROOT/data"
    BUILD_STATE="$BUILD_ROOT/state"
    BUILD_CACHE="$BUILD_ROOT/cache"

    mkdir -p "$BUILD_CONFIG" "$BUILD_DATA/nvim/site/pack/dist/start" "$BUILD_STATE" "$BUILD_CACHE"

    # Copy mason plugin to pack directory (auto-loaded)
    cp -r "$OFFLINE_DIR/lazy-plugins/mason.nvim" "$BUILD_DATA/nvim/site/pack/dist/start/"

    # Create init.lua with mason setup
    cat > "$BUILD_CONFIG/init.lua" << 'INITEOF'
-- Mason is auto-loaded from data/nvim/site/pack/dist/start/

-- Setup mason
require("mason").setup()

-- Install LSP servers
local function install_lsp()
    local lsp_str = vim.env.LSP_TO_INSTALL or ""

    for lsp in string.gmatch(lsp_str, "([^,]+)") do
        lsp = vim.trim(lsp)
        print("Installing: " .. lsp)
        vim.cmd("MasonInstall " .. lsp)
    end
end

-- Run after UI is ready
vim.defer_fn(function()
    install_lsp()
    -- Wait for installs to complete then quit
    vim.defer_fn(function()
        vim.cmd("q!")
    end, 120000)
end, 1000)
INITEOF

    echo "  Installing LSP: ${LSP_SERVERS//,/, }"

    # Run Neovim with our config
    XDG_CONFIG_HOME="$BUILD_ROOT/config" \
    XDG_DATA_HOME="$BUILD_DATA" \
    XDG_STATE_HOME="$BUILD_STATE" \
    XDG_CACHE_HOME="$BUILD_CACHE" \
    LSP_TO_INSTALL="$LSP_SERVERS" \
    nvim --headless 2>&1 || true

    # Copy Mason packages
    if [ -d "$BUILD_DATA/nvim/mason" ]; then
        cp -rv "$BUILD_DATA/nvim/mason" "$OFFLINE_DIR/"
        echo -e "  ${GREEN}Mason LSP servers installed${NC}"
    fi

    rm -rf "$BUILD_ROOT"
fi

# ============================================
# Create archive
# ============================================
echo ""
echo -e "${GREEN}Creating archive...${NC}"

# Copy install.sh into the package
cp "$SCRIPT_DIR/install.sh" "$OFFLINE_DIR/"

cd "$SCRIPT_DIR"
tar -czvf nvchad-offline.tar.gz nvchad-offline/

SIZE=$(du -h nvchad-offline.tar.gz | cut -f1)

echo ""
echo -e "${GREEN}============================================${NC}"
echo -e "${GREEN}Build complete!${NC}"
echo ""
echo "  Output: $SCRIPT_DIR/nvchad-offline.tar.gz"
echo "  Size: $SIZE"
echo ""
echo "Transfer to offline machine and run:"
echo "  ./install.sh"
echo -e "${GREEN}============================================${NC}"
