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
2. Visually select lines 10-23: `10GV23G`
3. Press `<leader>cv`
4. Type: `This is doing string search manually. Why not use string.find()?`

The `find()` function has a hand-rolled substring search that's a clear candidate for `string.find()`.

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

## 6. Float Mode

For users who prefer an overlay instead of a split.

1. Run: `:lua require("claudecode").config.ui.mode = "float"`
2. Press `<leader>cc` to open the floating chat
3. Type a message — the float window will auto-close when Claude proposes an edit so you can see the diff

To switch back: `:lua require("claudecode").config.ui.mode = "split"`
