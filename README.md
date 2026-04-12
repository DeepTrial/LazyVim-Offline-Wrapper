# NvChad Offline Installer

Bundle NvChad for offline installation on Ubuntu 20.04/22.04.

## Quick Start

### Option 1: GitHub Actions (Recommended)

1. Fork this repository
2. Actions → Build NvChad Offline Package → Run workflow
3. Download `nvchad-offline-ubuntu.tar.gz`
4. Transfer to offline machine and run `./install.sh`

### Option 2: Local Build

```bash
# Plugins only
./build.sh

# With Treesitter parsers
./build.sh --treesitter

# With Treesitter + Mason LSP
./build.sh --all

# Custom selection
./build.sh --treesitter lua,vim,python --mason lua_ls,pylsp
```

## Files

```
├── build.sh              # Build script (run online)
├── install.sh            # Install script (run offline)
└── .github/workflows/    # GitHub Actions
```

## glibc Compatibility

Built on Ubuntu 20.04 (glibc 2.31), compatible with:
- Ubuntu 20.04
- Ubuntu 22.04 (glibc 2.35)

Treesitter parsers and LSP binaries are forward-compatible with newer glibc.

## Included Plugins

- lazy.nvim, plenary.nvim
- base46 (themes), ui
- nvim-tree, telescope
- nvim-cmp, LuaSnip
- nvim-lspconfig, mason.nvim
- gitsigns, which-key, conform
- nvim-treesitter

## Default Components

| Component | Default |
|-----------|---------|
| Treesitter | lua, vim, vimdoc, python, javascript, typescript, json, html, css, bash, c, cpp |
| Mason LSP | lua_ls |

## Requirements

- Neovim >= 0.11
- Ubuntu 20.04 or 22.04 (for pre-built Treesitter/LSP)