# claudecode.nvim Feature Demos

This directory contains a small demo project for trying out (and screenshotting) every major feature.

## Setup

```sh
cd examples/demo-project
nvim taskmanager.lua
```

Make sure `claudecode.nvim` is installed and `:checkhealth claudecode` passes.

---

## 1. Chat in Split Mode (Hero Screenshot)

This is the main selling point — Claude right next to your code.

**Steps:**

1. Open `taskmanager.lua`
2. Press `<leader>cc` to open the chat split
3. Type: `What does this module do?`
4. Wait for Claude's response

**What to capture:** Both panes visible — code on the left, chat on the right with a full response rendered.

**Tip:** Resize the split so both sides are readable. `:vertical resize 85` on the chat window works well.

---

## 2. Inline Diff Viewer

Claude proposes edits, you accept or reject — just like Cursor.

**Steps:**

1. Open `taskmanager.lua`
2. Press `<leader>cc` to open chat
3. Type: `The add() function is deeply nested. Refactor it to use early returns and guard clauses.`
4. Claude will propose edits — the diff viewer opens automatically
5. You'll see deleted lines (red) and new lines (green) inline in the buffer
6. Press `<leader>cy` to accept or `<leader>cn` to reject

**What to capture:** The buffer showing red/green inline diff hunks with the hint text visible.

**Why this file:** The `add()` function (lines 5-43) is deliberately deeply nested with 6 levels of indentation — an obvious refactoring target that produces a dramatic diff.

---

## 3. Visual Selection Context

Select code and ask Claude about it specifically.

**Steps:**

1. Open `search.lua`
2. Move to line 10 (the `find` function's inner loop)
3. Visually select lines 10-23: `10GV23G`
4. Press `<leader>cv`
5. Type: `This is doing string search manually. Why not use string.find()?`

**What to capture:** The visual selection highlighted in the code, and the chat showing Claude's response about that specific block.

**Why this file:** The `find()` function has a hand-rolled substring search (byte-by-byte comparison) that's a clear candidate for `string.find()`. It makes for a great "ask about this code" demo.

---

## 4. Diagnostics Context

Send LSP errors and warnings to Claude for help.

**Steps:**

1. Open `formatter.lua` in Neovim with a Lua LSP configured (lua_ls)
2. Wait for diagnostics to appear — this file has several deliberate issues:
   - `unused_import` on line 3 (unused variable)
   - `json` on line 2 (unresolved require)
   - `task.prirotiy` on line 78 (typo — should be `priority`)
   - `PRIORTIY_COLORS` on line 7 (typo in variable name)
3. Press `<leader>cx` to send with file + diagnostics context
4. Type: `Fix the issues the LSP found`

**What to capture:** The buffer with visible diagnostic signs/underlines, and the chat showing Claude identifying and fixing each issue.

**Why this file:** It has realistic bugs — typos in variable names, an unused import, and a missing module. Exactly the kind of thing LSP catches and Claude can fix.

---

## 5. Session Picker

Resume a previous conversation.

**Steps:**

1. First, create a few sessions by doing demos 1-4 above (each opens a new session)
2. Close the chat with `q` in normal mode
3. Press `<leader>cl` to open the session picker
4. Browse through previous sessions, select one to resume

**What to capture:** The session picker floating over the code, showing 3-4 previous sessions with timestamps.

**Tip:** Do the other demos first so you have real session history to show.

---

## 6. Float Mode

For users who prefer an overlay instead of a split.

**Steps:**

1. Change your config:
   ```lua
   require("claudecode").setup({ ui = { mode = "float" } })
   ```
2. Open `taskmanager.lua`
3. Press `<leader>cc` to open the floating chat
4. Type a message so the chat has content

**What to capture:** The floating chat window with rounded borders, centered over the code buffer visible underneath.

---

## Screenshot Tips

- **Colorscheme:** Use something with good contrast — tokyonight, catppuccin, or gruvbox
- **Terminal size:** 120x35 characters minimum
- **Font size:** 14-16px so text is readable when scaled down on GitHub
- **Clean up:** Hide tmux bars, minimize distractions
- **Resolution:** Capture at 2x if your terminal supports it (for retina displays)
- **File names:** Name screenshots to match: `chat-split.png`, `inline-diff.png`, `visual-selection.png`, `diagnostics.png`, `session-picker.png`, `chat-float.png`

Put screenshots in a `screenshots/` directory at the repo root, then reference them in the README:

```markdown
![Chat split mode](screenshots/chat-split.png)
```
