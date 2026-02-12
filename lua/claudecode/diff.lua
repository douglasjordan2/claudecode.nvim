local M = {}

local pending_diffs = {}

function M.show(tool_use_id, input)
  if not input.file_path then
    return
  end

  local file_path = input.file_path
  local old_string = input.old_string or ""
  local new_string = input.new_string or ""

  if not vim.fn.filereadable(file_path) then
    return
  end

  local original_lines = vim.fn.readfile(file_path)
  local original_content = table.concat(original_lines, "\n")

  local modified_content = original_content:gsub(vim.pesc(old_string), new_string, 1)
  if modified_content == original_content then
    vim.notify("[claudecode] Could not find old_string in " .. file_path, vim.log.levels.WARN)
    return
  end

  pending_diffs[tool_use_id] = {
    file_path = file_path,
    new_content = modified_content,
  }

  local original_buf = vim.fn.bufnr(file_path, true)
  vim.cmd("tabnew")
  local tab = vim.api.nvim_get_current_tabpage()

  vim.api.nvim_set_current_buf(original_buf)
  vim.cmd("diffthis")

  vim.cmd("vsplit")
  local modified_buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_set_current_buf(modified_buf)
  vim.bo[modified_buf].filetype = vim.bo[original_buf].filetype
  vim.api.nvim_buf_set_lines(modified_buf, 0, -1, false, vim.split(modified_content, "\n"))
  vim.bo[modified_buf].modifiable = false
  vim.cmd("diffthis")

  vim.api.nvim_buf_set_name(modified_buf, "claudecode://diff/" .. vim.fn.fnamemodify(file_path, ":t"))

  local config = require("claudecode").config
  for _, buf in ipairs({ modified_buf, original_buf }) do
    vim.keymap.set("n", config.keymaps.accept_diff, function()
      M.accept(tool_use_id)
      vim.cmd("tabclose")
    end, { buffer = buf, desc = "Accept diff" })

    vim.keymap.set("n", config.keymaps.reject_diff, function()
      M.reject(tool_use_id)
      vim.cmd("tabclose")
    end, { buffer = buf, desc = "Reject diff" })
  end
end

function M.accept(tool_use_id)
  local diff = pending_diffs[tool_use_id]
  if not diff then
    vim.notify("[claudecode] No pending diff for " .. tool_use_id, vim.log.levels.WARN)
    return
  end

  local lines = vim.split(diff.new_content, "\n")
  vim.fn.writefile(lines, diff.file_path)

  local bufnr = vim.fn.bufnr(diff.file_path)
  if bufnr ~= -1 then
    vim.api.nvim_buf_call(bufnr, function()
      vim.cmd("edit!")
    end)
  end

  pending_diffs[tool_use_id] = nil
  vim.notify("[claudecode] Accepted edit to " .. diff.file_path)
end

function M.reject(tool_use_id)
  local diff = pending_diffs[tool_use_id]
  if not diff then
    return
  end

  pending_diffs[tool_use_id] = nil
  vim.notify("[claudecode] Rejected edit to " .. diff.file_path)
end

return M
