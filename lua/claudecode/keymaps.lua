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

  local sel_ns = vim.api.nvim_create_namespace("claudecode_selection")

  vim.keymap.set("v", km.visual, function()
    vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<Esc>", true, false, true), "nx", false)
    local bufnr = vim.api.nvim_get_current_buf()
    local ctx = context.selection()

    local start_line = vim.fn.getpos("'<")[2] - 1
    local end_line = vim.fn.getpos("'>")[2]
    for row = start_line, end_line - 1 do
      vim.api.nvim_buf_set_extmark(bufnr, sel_ns, row, 0, {
        line_hl_group = "Visual",
        end_row = row + 1,
      })
    end

    vim.ui.input({ prompt = "Claude (selection)> " }, function(input)
      vim.api.nvim_buf_clear_namespace(bufnr, sel_ns, 0, -1)
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
  local history = require("claudecode.chat").get_session_history()
  if #history == 0 then
    vim.notify("[claudecode] No sessions in this Neovim session", vim.log.levels.INFO)
    return
  end

  local labels = {}
  for i = #history, 1, -1 do
    local s = history[i]
    local time_str = os.date("%H:%M", s.timestamp)
    table.insert(labels, s.summary .. "  [" .. time_str .. "]")
  end

  vim.ui.select(labels, { prompt = "Resume session:" }, function(_, idx)
    if idx then
      local s = history[#history - idx + 1]
      require("claudecode.chat").resume(s.id)
    end
  end)
end

return M
