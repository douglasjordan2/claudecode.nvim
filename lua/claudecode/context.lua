local M = {}

function M.current_file()
  local bufnr = vim.api.nvim_get_current_buf()
  local path = vim.api.nvim_buf_get_name(bufnr)
  if path == "" then
    return nil
  end

  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local content = table.concat(lines, "\n")
  local ft = vim.bo[bufnr].filetype

  return string.format("File: %s (%s)\n```%s\n%s\n```", path, ft, ft, content)
end

function M.selection()
  local bufnr = vim.api.nvim_get_current_buf()
  local path = vim.api.nvim_buf_get_name(bufnr)
  local ft = vim.bo[bufnr].filetype

  local start_pos = vim.fn.getpos("'<")
  local end_pos = vim.fn.getpos("'>")
  local start_line = start_pos[2]
  local end_line = end_pos[2]

  if start_line == 0 or end_line == 0 then
    return nil
  end

  local lines = vim.api.nvim_buf_get_lines(bufnr, start_line - 1, end_line, false)
  local content = table.concat(lines, "\n")

  return string.format(
    "File: %s (lines %d-%d, %s)\n```%s\n%s\n```",
    path, start_line, end_line, ft, ft, content
  )
end

function M.diagnostics()
  local bufnr = vim.api.nvim_get_current_buf()
  local path = vim.api.nvim_buf_get_name(bufnr)
  local diags = vim.diagnostic.get(bufnr)

  if #diags == 0 then
    return nil
  end

  local lines = { "Diagnostics for " .. path .. ":" }
  for _, d in ipairs(diags) do
    local severity = vim.diagnostic.severity[d.severity] or "?"
    table.insert(lines, string.format("  Line %d: [%s] %s", d.lnum + 1, severity, d.message))
  end

  return table.concat(lines, "\n")
end

function M.gather(include_file, include_selection, include_diagnostics)
  local parts = {}

  if include_selection then
    local sel = M.selection()
    if sel then
      table.insert(parts, sel)
    end
  end

  if include_file then
    local file = M.current_file()
    if file then
      table.insert(parts, file)
    end
  end

  if include_diagnostics then
    local diag = M.diagnostics()
    if diag then
      table.insert(parts, diag)
    end
  end

  if #parts == 0 then
    return nil
  end

  return table.concat(parts, "\n\n")
end

return M
