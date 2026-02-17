# Try claudecode.nvim

This directory contains a small demo project for trying out every major feature.

## Setup

```sh
cd examples/demo-project
nvim taskmanager.lua
```

Make sure `claudecode.nvim` is installed and `:checkhealth claudecode` passes.

---

## 1. Chat in Split Mode

Open a file and start chatting with Claude right next to your code.

1. Open `taskmanager.lua`
2. Press `<leader>cc` to open the chat split
3. Type: `What does this module do?`
4. Wait for Claude's response

You'll see both panes — code on the left, chat on the right.

---

## 2. Inline Diff Viewer

Claude proposes edits, you accept or reject — just like Cursor.

1. Open `taskmanager.lua`
2. Press `<leader>cc` to open chat
3. Type: `The add() function is deeply nested. Refactor it to use early returns and guard clauses.`
4. Claude will propose edits — the diff viewer opens automatically
5. Deleted lines appear in red, new lines in green as virtual text
6. Press `<leader>cy` to accept or `<leader>cn` to reject

The `add()` function is deliberately deeply nested (6 levels) — an obvious refactoring target.

---

## 3. Visual Selection Context

Select code and ask Claude about it specifically.

1. Open `search.lua`
2. Visually select the `find()` function: `3GV16G`
3. Press `<leader>cv`
4. Type: `This uses numeric indexing. Would ipairs be better here?`

The `find()` function uses `for i = 1, #tasks` with manual indexing instead of `ipairs`.

---

## 4. Diagnostics Context

Send LSP errors and warnings to Claude for help.

1. Open `formatter.lua` with a Lua LSP configured (lua_ls)
2. Wait for diagnostics — this file has deliberate issues:
   - `unused_import` on line 2 (unused variable)
   - `require("json")` on line 1 (unresolved module)
   - `task.prirotiy` on line 76 (typo — should be `priority`)
   - `PRIORTIY_COLORS` on line 5 (typo in variable name)
3. Press `<leader>cx` to send with file + diagnostics context
4. Type: `Fix the issues the LSP found`

---

## 5. Session Management

Resume a previous conversation from this Neovim session.

1. First, create a few sessions by doing demos 1-4 above
2. Close the chat with `<leader>cc`
3. Press `<leader>cl` to open the session picker
4. Select a previous session to resume

Sessions are scoped to the current Neovim instance.

---

## 6. Inline Edit

Select code, type an instruction, and Claude edits it in-place — no chat panel needed.

1. Open `search.lua`
2. Visually select the `find_by_date_range()` function: `18GV28G`
3. Press `<leader>ce`
4. The selection stays highlighted and a prompt appears: `Edit instruction>`
5. Type: `Combine the nested if statements into a single condition`
6. Claude sends an Edit — the inline diff viewer shows the proposed change
7. Press `<leader>cy` to accept or `<leader>cn` to reject

This is the Cursor Cmd+K equivalent — targeted edits without opening the chat.

---

## 7. Statusline

See Claude's current state in your statusline.

1. Add to your lualine config:
   ```lua
   lualine_x = { require("claudecode").statusline }
   ```
2. Restart Neovim — you'll see `󰚩 Claude` in the statusline (idle)
3. Send a message with `<leader>cc` — watch the icon change:
   - `󱜸 Claude [thinking]` — waiting for first response
   - `󰊳 Claude [streaming]` — text is streaming in
   - `󰒓 Claude [tool_use]` — Claude is using a tool
   - `󰚩 Claude` — back to idle when done

You can also check the raw state programmatically: `:lua print(require("claudecode").get_state())`

---

## 8. Float Mode

For users who prefer an overlay instead of a split.

1. Run: `:lua require("claudecode").config.ui.mode = "float"`
2. Press `<leader>cc` to open the floating chat
3. Type a message — the float window will auto-close when Claude proposes an edit so you can see the diff

To switch back: `:lua require("claudecode").config.ui.mode = "split"`
