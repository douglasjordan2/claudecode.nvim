local M = {}

local chat_buf = nil
local chat_win = nil
local input_buf = nil
local input_win = nil

local function get_config()
  return require("claudecode").config.ui
end

local function input_min_height()
  return get_config().input_min_height or 2
end

local function input_max_height()
  return get_config().input_max_height or 10
end

local function create_chat_buf()
  if chat_buf and vim.api.nvim_buf_is_valid(chat_buf) then
    return chat_buf
  end

  chat_buf = vim.api.nvim_create_buf(false, true)
  vim.bo[chat_buf].buftype = "nofile"
  vim.bo[chat_buf].swapfile = false
  vim.bo[chat_buf].filetype = "markdown"
  vim.bo[chat_buf].bufhidden = "hide"
  vim.bo[chat_buf].modifiable = false
  vim.api.nvim_buf_set_name(chat_buf, "claudecode://chat")

  return chat_buf
end

local function send_input()
  if not input_buf or not vim.api.nvim_buf_is_valid(input_buf) then
    return
  end

  local lines = vim.api.nvim_buf_get_lines(input_buf, 0, -1, false)
  local text = table.concat(lines, "\n")
  text = vim.trim(text)
  if text == "" then
    return
  end

  vim.api.nvim_buf_set_lines(input_buf, 0, -1, false, { "" })

  if input_win and vim.api.nvim_win_is_valid(input_win) then
    vim.api.nvim_win_set_height(input_win, input_min_height())
    vim.api.nvim_win_set_cursor(input_win, { 1, 0 })
  end

  require("claudecode.chat").send(text)
end

local function auto_resize_input()
  if not input_buf or not vim.api.nvim_buf_is_valid(input_buf) then
    return
  end
  if not input_win or not vim.api.nvim_win_is_valid(input_win) then
    return
  end

  local line_count = vim.api.nvim_buf_line_count(input_buf)
  local height = math.max(input_min_height(), math.min(line_count, input_max_height()))
  vim.api.nvim_win_set_height(input_win, height)
end

local function create_input_buf()
  if input_buf and vim.api.nvim_buf_is_valid(input_buf) then
    return input_buf
  end

  input_buf = vim.api.nvim_create_buf(false, true)
  vim.bo[input_buf].buftype = "nofile"
  vim.bo[input_buf].swapfile = false
  vim.bo[input_buf].filetype = "markdown"
  vim.bo[input_buf].bufhidden = "hide"
  vim.api.nvim_buf_set_name(input_buf, "claudecode://input")

  vim.keymap.set("i", "<C-s>", send_input, { buffer = input_buf, desc = "Send to Claude" })
  vim.keymap.set("n", "<CR>", send_input, { buffer = input_buf, desc = "Send to Claude" })
  vim.keymap.set("n", "q", function()
    M.close()
  end, { buffer = input_buf, desc = "Close Claude chat" })

  vim.api.nvim_create_autocmd({ "TextChanged", "TextChangedI" }, {
    buffer = input_buf,
    callback = auto_resize_input,
  })

  return input_buf
end

function M.get_chat_buf()
  return create_chat_buf()
end

function M.get_chat_win()
  return chat_win
end

local function apply_win_opts(win)
  vim.wo[win].number = false
  vim.wo[win].relativenumber = false
  vim.wo[win].signcolumn = "no"
  vim.wo[win].wrap = true
  vim.wo[win].linebreak = true
end

function M.open(mode)
  if chat_win and vim.api.nvim_win_is_valid(chat_win) then
    if input_win and vim.api.nvim_win_is_valid(input_win) then
      vim.api.nvim_set_current_win(input_win)
    else
      vim.api.nvim_set_current_win(chat_win)
    end
    return
  end

  local cfg = get_config()
  mode = mode or cfg.mode
  local cb = create_chat_buf()
  local ib = create_input_buf()

  if mode == "float" then
    local width = math.floor(vim.o.columns * cfg.float_width)
    local total_height = math.floor(vim.o.lines * cfg.float_height)
    local chat_height = total_height - input_min_height() - 2
    local row = math.floor((vim.o.lines - total_height) / 2)
    local col = math.floor((vim.o.columns - width) / 2)

    chat_win = vim.api.nvim_open_win(cb, true, {
      relative = "editor",
      width = width,
      height = chat_height,
      row = row,
      col = col,
      style = "minimal",
      border = cfg.border,
      title = " Claude Code ",
      title_pos = "center",
    })

    input_win = vim.api.nvim_open_win(ib, true, {
      relative = "editor",
      width = width,
      height = input_min_height(),
      row = row + chat_height + 2,
      col = col,
      style = "minimal",
      border = cfg.border,
      title = " Input (C-s to send) ",
      title_pos = "center",
    })
  else
    vim.cmd("botright vsplit")
    chat_win = vim.api.nvim_get_current_win()
    vim.api.nvim_win_set_buf(chat_win, cb)
    vim.api.nvim_win_set_width(chat_win, cfg.split_width)
    vim.wo[chat_win].winfixwidth = true

    vim.cmd("belowright split")
    input_win = vim.api.nvim_get_current_win()
    vim.api.nvim_win_set_buf(input_win, ib)
    vim.api.nvim_win_set_height(input_win, input_min_height())
    vim.wo[input_win].winfixheight = true
    vim.wo[input_win].winfixwidth = true
  end

  apply_win_opts(chat_win)
  apply_win_opts(input_win)

  vim.api.nvim_set_current_win(input_win)
  vim.api.nvim_win_set_cursor(input_win, { 1, 0 })
  vim.cmd("startinsert")
end

function M.close()
  if input_win and vim.api.nvim_win_is_valid(input_win) then
    vim.api.nvim_win_close(input_win, true)
  end
  if chat_win and vim.api.nvim_win_is_valid(chat_win) then
    vim.api.nvim_win_close(chat_win, true)
  end
  chat_win = nil
  input_win = nil
end

function M.toggle()
  if chat_win and vim.api.nvim_win_is_valid(chat_win) then
    M.close()
  else
    M.open()
  end
end

function M.is_open()
  return chat_win and vim.api.nvim_win_is_valid(chat_win)
end

function M.focus_input()
  if input_win and vim.api.nvim_win_is_valid(input_win) then
    vim.api.nvim_set_current_win(input_win)
    vim.cmd("startinsert!")
  else
    M.open()
  end
end

return M
