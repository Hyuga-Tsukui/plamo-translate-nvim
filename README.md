# plamo-translate-nvim

A Neovim plugin that provides seamless integration with [plamo-translate-cli](https://github.com/pfnet/plamo-translate-cli).

## About

This plugin is a simple Neovim wrapper for the excellent [plamo-translate-cli](https://github.com/pfnet/plamo-translate-cli) tool developed by Preferred Networks (PFN). All translation functionality is powered by plamo-translate-cli - this plugin merely provides a convenient interface for Neovim users.

**Full credit and gratitude goes to the PFN team and plamo-translate-cli contributors for creating the amazing translation tool that makes this plugin possible.**

## Features

- 🔤 Translate selected text directly in Neovim
- 📺 Real-time translation display with streaming output
- 📝 Buffer-based translation results for easy text manipulation
- 🔄 Automatic server management
- 🎯 Simple visual selection workflow

## Why Buffer-Based Translation?

Unlike simple popup notifications, this plugin displays translation results in a dedicated buffer, allowing you to:

- **Copy and paste** translated text easily
- **Edit and refine** translations as needed
- **Navigate** through long translations with Vim motions
- **Search** within translation results using `/` and `?`
- **Save** translations to files for future reference
- **Use Vim's powerful text manipulation** features on translated content

This approach integrates translation seamlessly into your existing Vim/Neovim workflow.

## Requirements

- Neovim 0.10+
- **[plamo-translate-cli](https://github.com/pfnet/plamo-translate-cli)** (required)

## Installation

### 1. Install plamo-translate-cli

First, install the plamo-translate-cli tool:

```bash
# Follow instructions at: https://github.com/pfnet/plamo-translate-cli
```

### 2. Install the Neovim plugin

#### Using [lazy.nvim](https://github.com/folke/lazy.nvim)

```lua
{
    "Hyuga-Tsukui/plamo-translate-nvim",
    keys = {
        {
            "<leader>ts",
            "<cmd>PlamoTranslateSelection<cr>",
            desc = "Translate Selection",
            mode = {"v", "n"}
        },
    },
}
```

## Usage

### Basic Workflow

1. Select text in visual mode
2. Run `:PlamoTranslateSelection`
3. View translation in the split window
4. Use normal Vim operations (copy, edit, search, save) on the translation results

### Commands

| Command                      | Description                               |
| ---------------------------- | ----------------------------------------- |
| `:PlamoTranslateSelection`   | Translate currently selected text         |
| `:PlamoTranslateServerStart` | Manually start the plamo-translate server |
| `:PlamoTranslateServerStop`  | Manually stop the plamo-translate server  |

### Key Mappings (Optional)

Add these to your configuration for quicker access:

```lua
-- Example key mappings
vim.keymap.set("v", "<leader>ts", ":PlamoTranslateSelection<CR>", { desc = "Translate selection" })
vim.keymap.set("n", "<leader>ts", ":PlamoTranslateSelection<CR>", , { desc = "Translate selection" })
```

## Configuration

The plugin works out of the box with default settings:

```lua
require("plamo-translate-nvim").setup()
```

## Troubleshooting

### "plamo-translate command not found"

Make sure plamo-translate-cli is installed and available in your PATH:

```bash
plamo-translate --version
```

If not installed, please follow the installation guide at: https://github.com/pfnet/plamo-translate-cli

### Server Issues

If you encounter server-related problems, try stopping and restarting:

```vim
:PlamoTranslateServerStop
" Then try translating again - the server will restart automatically
```

## Acknowledgments

This plugin is built upon the fantastic work of:

- **Preferred Networks (PFN)** and the **plamo-translate-cli team** for creating the core translation functionality
- The plamo-translate-cli project: https://github.com/pfnet/plamo-translate-cli

Without their excellent tool, this Neovim integration would not exist. Please consider starring and supporting the original plamo-translate-cli repository.

## License

[MIT License](LICENSE)

## Contributing

Contributions are welcome! Please feel free to submit issues and pull requests.

For translation-related improvements, consider contributing to the upstream [plamo-translate-cli](https://github.com/pfnet/plamo-translate-cli) project as well.
