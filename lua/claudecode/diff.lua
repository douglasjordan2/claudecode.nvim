local M = {}

local ns = vim.api.nvim_create_namespace("claudecode_inline_diff")
local pending_diffs = {}

local function setup_highlights()
  vim.api.nvim_set_hl(0, "ClaudeCodeDiffAdd", { default = true, link = "DiffAdd" })
  vim.api.nvim_set_hl(0, "ClaudeCodeDiffDelete", { default = true, link = "DiffDelete" })
  vim.api.nvim_set_hl(0, "ClaudeCodeDiffHint", { default = true, link = "Comment" })
end

local function file_has_pending_diff(file_path)
  for _, diff in pairs(pending_diffs) do
    if diff.file_path == file_path then
      return true
    end
  end
  return false
end

local function compute_hunks(orig_text, mod_text)
  return vim.diff(orig_text, mod_text, { result_type = "indices" })
end

local function render_inline(bufnr, hunks, orig_lines)
  local extmark_ids = {}
  local line_count = vim.api.nvim_buf_line_count(bufnr)

  for _, hunk in ipairs(hunks) do
    local start_a, count_a, start_b, count_b = hunk[1], hunk[2], hunk[3], hunk[4]

    if count_a > 0 then
      local virt_lines = {}
      for i = start_a, start_a + count_a - 1 do
        table.insert(virt_lines, { { orig_lines[i] or "", "ClaudeCodeDiffDelete" } })
      end

      local anchor_row, above
      if count_b > 0 then
        anchor_row = start_b - 1
        above = true
      elseif start_b == 0 then
        anchor_row = 0
        above = true
      elseif start_b < line_count then
        anchor_row = start_b
        above = true
      else
        anchor_row = line_count - 1
        above = false
      end

      local id = vim.api.nvim_buf_set_extmark(bufnr, ns, anchor_row, 0, {
        virt_lines = virt_lines,
        virt_lines_above = above,
      })
      table.insert(extmark_ids, id)
    end

    if count_b > 0 then
      for i = 0, count_b - 1 do
        local row = start_b - 1 + i
        local id = vim.api.nvim_buf_set_extmark(bufnr, ns, row, 0, {
          line_hl_group = "ClaudeCodeDiffAdd",
        })
        table.insert(extmark_ids, id)
      end
    end
  end

  return extmark_ids
end

local function render_hint(bufnr, hunks)
  if #hunks == 0 then
    return nil
  end

  local config = require("claudecode").config
  local accept_key = config.keymaps.accept_diff
  local reject_key = config.keymaps.reject_diff

  local first_hunk = hunks[1]
  local hint_row
  if first_hunk[4] > 0 then
    hint_row = first_hunk[3] - 1
  elseif first_hunk[3] > 0 then
    hint_row = first_hunk[3] - 1
  else
    hint_row = 0
  end

  local hint_text = string.format("  [%s] Accept  [%s] Reject", accept_key, reject_key)
  return vim.api.nvim_buf_set_extmark(bufnr, ns, hint_row, 0, {
    virt_text = { { hint_text, "ClaudeCodeDiffHint" } },
    virt_text_pos = "eol",
  })
end

local function clear_decorations(tool_use_id)
  local diff = pending_diffs[tool_use_id]
  if not diff then
    return
  end
  if vim.api.nvim_buf_is_valid(diff.bufnr) then
    vim.api.nvim_buf_clear_namespace(diff.bufnr, ns, 0, -1)
  end
end

local function set_buffer_keymaps(bufnr, tool_use_id)
  local config = require("claudecode").config
  vim.keymap.set("n", config.keymaps.accept_diff, function()
    M.accept(tool_use_id)
  end, { buffer = bufnr, desc = "Accept inline diff" })
  vim.keymap.set("n", config.keymaps.reject_diff, function()
    M.reject(tool_use_id)
  end, { buffer = bufnr, desc = "Reject inline diff" })
end

local function remove_buffer_keymaps(tool_use_id)
  local diff = pending_diffs[tool_use_id]
  if not diff or not vim.api.nvim_buf_is_valid(diff.bufnr) then
    return
  end
  local config = require("claudecode").config
  pcall(vim.keymap.del, "n", config.keymaps.accept_diff, { buffer = diff.bufnr })
  pcall(vim.keymap.del, "n", config.keymaps.reject_diff, { buffer = diff.bufnr })
end

function M.show(tool_use_id, input)
  if not input or not input.file_path then
    return
  end

  local file_path = input.file_path
  local old_string = input.old_string or ""
  local new_string = input.new_string or ""

  if vim.fn.filereadable(file_path) ~= 1 then
    return
  end

  if file_has_pending_diff(file_path) then
    vim.notify("[claudecode] File already has a pending diff: " .. file_path, vim.log.levels.WARN)
    return
  end

  setup_highlights()

  local bufnr = vim.fn.bufnr(file_path)
  if bufnr == -1 then
    vim.cmd("edit " .. vim.fn.fnameescape(file_path))
    bufnr = vim.api.nvim_get_current_buf()
  else
    local wins = vim.fn.win_findbuf(bufnr)
    if #wins > 0 then
      vim.api.nvim_set_current_win(wins[1])
    else
      vim.cmd("edit " .. vim.fn.fnameescape(file_path))
    end
  end

  local original_lines
  if vim.bo[bufnr].modified then
    original_lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  else
    original_lines = vim.fn.readfile(file_path)
  end
  local original_content = table.concat(original_lines, "\n")

  local escaped_new = new_string:gsub("%%", "%%%%")
  local modified_content = original_content:gsub(vim.pesc(old_string), escaped_new, 1)
  if modified_content == original_content then
    vim.notify("[claudecode] Could not find old_string in " .. file_path, vim.log.levels.WARN)
    return
  end

  local modified_lines = vim.split(modified_content, "\n")
  local hunks = compute_hunks(original_content .. "\n", modified_content .. "\n")

  if not hunks or #hunks == 0 then
    vim.notify("[claudecode] No differences found", vim.log.levels.WARN)
    return
  end

  vim.bo[bufnr].modifiable = true
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, modified_lines)
  vim.bo[bufnr].modifiable = false

  local extmark_ids = render_inline(bufnr, hunks, original_lines)
  local hint_id = render_hint(bufnr, hunks)
  if hint_id then
    table.insert(extmark_ids, hint_id)
  end

  set_buffer_keymaps(bufnr, tool_use_id)

  local first_hunk = hunks[1]
  local jump_line
  if first_hunk[4] > 0 then
    jump_line = first_hunk[3]
  elseif first_hunk[3] > 0 then
    jump_line = first_hunk[3]
  else
    jump_line = 1
  end
  local buf_lines = vim.api.nvim_buf_line_count(bufnr)
  if jump_line > buf_lines then
    jump_line = buf_lines
  end
  vim.api.nvim_win_set_cursor(0, { jump_line, 0 })

  pending_diffs[tool_use_id] = {
    file_path = file_path,
    bufnr = bufnr,
    original_lines = original_lines,
    modified_lines = modified_lines,
    extmark_ids = extmark_ids,
  }
end

function M.accept(tool_use_id)
  local diff = pending_diffs[tool_use_id]
  if not diff then
    vim.notify("[claudecode] No pending diff for " .. tool_use_id, vim.log.levels.WARN)
    return
  end

  if not vim.api.nvim_buf_is_valid(diff.bufnr) then
    pending_diffs[tool_use_id] = nil
    return
  end

  vim.bo[diff.bufnr].modifiable = true
  vim.fn.writefile(diff.modified_lines, diff.file_path)
  vim.bo[diff.bufnr].modified = false

  clear_decorations(tool_use_id)
  remove_buffer_keymaps(tool_use_id)
  pending_diffs[tool_use_id] = nil

  vim.notify("[claudecode] Accepted edit to " .. diff.file_path)
end

function M.reject(tool_use_id)
  local diff = pending_diffs[tool_use_id]
  if not diff then
    return
  end

  if not vim.api.nvim_buf_is_valid(diff.bufnr) then
    pending_diffs[tool_use_id] = nil
    return
  end

  vim.bo[diff.bufnr].modifiable = true
  vim.api.nvim_buf_set_lines(diff.bufnr, 0, -1, false, diff.original_lines)
  vim.bo[diff.bufnr].modified = false

  clear_decorations(tool_use_id)
  remove_buffer_keymaps(tool_use_id)
  pending_diffs[tool_use_id] = nil

  vim.notify("[claudecode] Rejected edit to " .. diff.file_path)
end

return M
