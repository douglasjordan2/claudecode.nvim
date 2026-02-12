local M = {}

function M.setup(config)
  local chat = require("claudecode.chat")
  local context = require("claudecode.context")
  local ui = require("claudecode.ui")
  local km = config.keymaps

  vim.keymap.set("n", km.toggle, function()
    ui.toggle()
  end, { desc = "Claude: Toggle chat" })

  vim.keymap.set("n", km.send, function()
    ui.focus_input()
  end, { desc = "Claude: Focus input" })

  vim.keymap.set("n", km.context, function()
    local ctx = context.gather(true, false, true)
    vim.ui.input({ prompt = "Claude (with file)> " }, function(input)
      if input and input ~= "" then
        chat.send(input, ctx)
      end
    end)
  end, { desc = "Claude: Send with context" })

  vim.keymap.set("v", km.visual, function()
    vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<Esc>", true, false, true), "nx", false)
    local ctx = context.selection()
    vim.ui.input({ prompt = "Claude (selection)> " }, function(input)
      if input and input ~= "" then
        chat.send(input, ctx)
      end
    end)
  end, { desc = "Claude: Send selection" })

  vim.keymap.set("n", km.abort, function()
    chat.abort()
  end, { desc = "Claude: Abort" })

  vim.keymap.set("n", km.sessions, function()
    M.session_picker()
  end, { desc = "Claude: Sessions" })
end

function M.session_picker()
  local sessions = {}
  local session_dir = vim.fn.expand("~/.claude/sessions")
  if vim.fn.isdirectory(session_dir) == 0 then
    vim.notify("[claudecode] No sessions directory found", vim.log.levels.INFO)
    return
  end

  local files = vim.fn.glob(session_dir .. "/*.json", false, true)
  for _, f in ipairs(files) do
    local name = vim.fn.fnamemodify(f, ":t:r")
    table.insert(sessions, name)
  end

  if #sessions == 0 then
    vim.notify("[claudecode] No sessions found", vim.log.levels.INFO)
    return
  end

  vim.ui.select(sessions, { prompt = "Resume session:" }, function(choice)
    if choice then
      require("claudecode.chat").resume(choice)
    end
  end)
end

return M
