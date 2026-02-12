# claudecode.nvim

A Neovim plugin that provides an in-editor chat interface to [Claude Code](https://docs.anthropic.com/en/docs/claude-code) via a Rust bridge binary.

> **No API key required.** This plugin runs through the Claude Code CLI, which uses
> your existing Claude Pro or Max subscription. Unlike API-based plugins, there are
> no per-token costs or separate billing — just your monthly plan.

<!-- Screenshot/demo placeholder -->

## Requirements

- Neovim 0.10+
- [Claude CLI](https://docs.anthropic.com/en/docs/claude-code) (`claude` must be on your PATH)
- Rust toolchain (only if no prebuilt binary is available for your platform)

## Installation

### lazy.nvim

```lua
{
  "douglasjordan2/claudecode.nvim",
  build = function()
    require("claudecode.build").install()
  end,
  config = function()
    require("claudecode").setup()
  end,
}
```

### packer.nvim

```lua
use {
  "douglasjordan2/claudecode.nvim",
  run = function()
    require("claudecode.build").install()
  end,
  config = function()
    require("claudecode").setup()
  end,
}
```

### Manual

Clone the repo into your Neovim packages directory, then build the bridge:

```sh
cd ~/.local/share/nvim/site/pack/plugins/start/claudecode.nvim
lua -e "require('claudecode.build').install()"
```

## Quick Start

```lua
require("claudecode").setup()
```

Open Neovim and press `<leader>cc` to toggle the chat window, or run `:Claude hello` to send a message.

## Configuration

```lua
require("claudecode").setup({
  ui = {
    mode = "split",           -- "split" or "float"
    split_width = 80,         -- width of split panel
    float_width = 0.7,        -- float width (0-1 = fraction, >1 = pixels)
    float_height = 0.8,       -- float height (0-1 = fraction, >1 = pixels)
    border = "rounded",       -- border style for float windows
    input_min_height = 2,     -- minimum height of the input box
    input_max_height = 10,    -- maximum height of the input box
  },
  keymaps = {
    toggle = "<leader>cc",    -- toggle chat window
    send = "<leader>cs",      -- focus input
    context = "<leader>cx",   -- send with file context
    visual = "<leader>cv",    -- send visual selection
    abort = "<leader>ca",     -- abort current request
    accept_diff = "<leader>cy", -- accept diff in diff viewer
    reject_diff = "<leader>cn", -- reject diff in diff viewer
    sessions = "<leader>cl",  -- list/resume sessions
  },
  truncation = {
    tool_result = 120,        -- max length for tool result display
    command = 60,             -- max length for command display
  },
  model = nil,                -- override Claude model
  allowed_tools = nil,        -- restrict available tools
  append_system_prompt = nil, -- append to system prompt
  permission_mode = nil,      -- permission mode for claude CLI
  binary_path = nil,          -- custom path to bridge binary
})
```

## Commands

| Command          | Description                              |
|------------------|------------------------------------------|
| `:Claude [msg]`  | Toggle chat, or send a message           |
| `:ClaudeChat`    | Open chat and focus input                |
| `:ClaudeAbort`   | Abort the active request                 |
| `:ClaudeSessions`| List and resume previous sessions        |
| `:ClaudeStatus`  | Show bridge status                       |
| `:ClaudeNew`     | Start a new session                      |

## Keymaps

### Global (normal mode)

| Key              | Action                     |
|------------------|----------------------------|
| `<leader>cc`     | Toggle chat window         |
| `<leader>cs`     | Focus chat input           |
| `<leader>cx`     | Send with file context     |
| `<leader>ca`     | Abort current request      |
| `<leader>cl`     | Session picker             |

### Visual mode

| Key              | Action                     |
|------------------|----------------------------|
| `<leader>cv`     | Send selection to Claude   |

### Chat input buffer

| Key              | Action                     |
|------------------|----------------------------|
| `<C-s>` (insert) | Send message              |
| `<CR>` (normal)  | Send message              |
| `q` (normal)     | Close chat                |

### Diff viewer

| Key              | Action                     |
|------------------|----------------------------|
| `<leader>cy`     | Accept proposed edit       |
| `<leader>cn`     | Reject proposed edit       |

## Architecture

```
Neovim (Lua) <--stdin/stdout JSON-lines--> claudecode-bridge (Rust) <--spawns--> claude CLI
```

The plugin communicates with a Rust bridge binary over stdin/stdout using JSON-lines protocol. The bridge spawns the `claude` CLI process, streams its output, and forwards structured events back to Neovim. This architecture keeps the Lua side lightweight and avoids blocking the editor during long-running requests.

Key modules:
- `lua/claudecode/init.lua` - setup, config, user commands
- `lua/claudecode/bridge.lua` - manages the bridge subprocess
- `lua/claudecode/chat.lua` - event handling and chat rendering
- `lua/claudecode/ui.lua` - split/float window management
- `lua/claudecode/context.lua` - file/selection/diagnostics context
- `lua/claudecode/diff.lua` - diff viewer for Edit tool
- `lua/claudecode/keymaps.lua` - keymap registration
- `lua/claudecode/build.lua` - binary download/build

## Troubleshooting

Run `:checkhealth claudecode` to diagnose common issues.

Common problems:

- **Bridge binary not found**: Run `:lua require('claudecode.build').install()` or build manually with `cd rust && cargo build --release`
- **`claude` not on PATH**: Install the Claude CLI and ensure it's accessible
- **No output after sending**: Check `:ClaudeStatus` to verify the bridge is running. Check stderr output in the chat buffer for errors from the CLI.

## License

MIT
