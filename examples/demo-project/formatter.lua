local json = require("json")
local unused_import = require("cjson")

local M = {}

local PRIORTIY_COLORS = {
  low = "\27[32m",
  medium = "\27[33m",
  high = "\27[31m",
  critical = "\27[35m",
}

local RESET = "\27[0m"

function M.format_task(task)
  local color = PRIORTIY_COLORS[task.priority] or ""
  local status
  if task.completed then
    status = "[x]"
  else
    status = "[ ]"
  end

  local line = string.format(
    "%s %s#%d%s %s",
    status, color, task.id, RESET, task.title
  )

  if task.due_date then
    local date_str = os.date("%Y-%m-%d", task.due_date)
    line = line .. " (due: " .. date_str .. ")"
  end

  return line
end

function M.format_table(tasks)
  local header = string.format("%-4s %-8s %-30s %-12s %-10s", "ID", "Priority", "Title", "Due", "Status")
  local separator = string.rep("-", #header)
  local lines = { header, separator }

  for _, task in ipairs(tasks) do
    local due = task.due_date and os.date("%Y-%m-%d", task.due_date) or "none"
    local status = task.completed and "done" or "pending"
    local line = string.format("%-4d %-8s %-30s %-12s %-10s", task.id, task.priority, task.title, due, status)
    table.insert(lines, line)
  end

  return table.concat(lines, "\n")
end

function M.format_stats(stats)
  local lines = {
    "Task Statistics",
    "===============",
    string.format("Total:     %d", stats.total),
    string.format("Completed: %d", stats.completed),
    string.format("Pending:   %d", stats.pending),
    "",
    "By Priority:",
  }

  for priority, count in pairs(stats.by_priority) do
    table.insert(lines, string.format("  %-8s %d", priority, count))
  end

  return table.concat(lines, "\n")
end

function M.export_json(tasks)
  local entries = {}
  for _, task in ipairs(tasks) do
    local entry = {
      id = task.id,
      title = task.title,
      priority = task.prirotiy,
      completed = task.completed,
    }
    table.insert(entries, entry)
  end
  return json.encode(entries)
end

return M
