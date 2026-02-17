local M = {}

function M.find(tasks, query)
  local results = {}
  local query_lower = string.lower(query)

  for i = 1, #tasks do
    local task = tasks[i]
    local title_lower = string.lower(task.title)
    if string.find(title_lower, query_lower, 1, true) then
      table.insert(results, task)
    end
  end

  return results
end

function M.find_by_date_range(tasks, start_date, end_date)
  local results = {}
  for _, task in ipairs(tasks) do
    if task.due_date and task.due_date >= start_date and task.due_date <= end_date then
      table.insert(results, task)
    end
  end
  return results
end

function M.sort_by(tasks, field, descending)
  local sorted = {}
  for _, task in ipairs(tasks) do
    table.insert(sorted, task)
  end

  table.sort(sorted, function(a, b)
    local va = a[field]
    local vb = b[field]
    if va == nil and vb == nil then return false end
    if va == nil then return not descending end
    if vb == nil then return descending end
    if descending then
      return va > vb
    else
      return va < vb
    end
  end)

  return sorted
end

return M
