local M = {}

M.tasks = {}

function M.add(title, priority, due_date)
  if not title then return nil, "title is required" end
  if type(title) ~= "string" then return nil, "title must be a string" end
  if #title == 0 then return nil, "title cannot be empty" end

  local valid_priorities = { low = true, medium = true, high = true, critical = true }
  if priority and not valid_priorities[priority] then
    return nil, "invalid priority: must be low, medium, high, or critical"
  end

  if due_date and type(due_date) ~= "number" then
    return nil, "due_date must be a number"
  end

  local task = {
    id = #M.tasks + 1,
    title = title,
    priority = priority or "medium",
    due_date = due_date,
    created_at = os.time(),
    completed = false,
  }
  table.insert(M.tasks, task)
  return task
end

function M.complete(id)
  for _, task in ipairs(M.tasks) do
    if task.id == id then
      task.completed = true
      task.completed_at = os.time()
      return task
    end
  end
  return nil, "task not found"
end

function M.list(filter)
  local result = {}
  for _, task in ipairs(M.tasks) do
    if filter == nil then
      table.insert(result, task)
    elseif filter == "pending" and not task.completed then
      table.insert(result, task)
    elseif filter == "done" and task.completed then
      table.insert(result, task)
    elseif filter == task.priority then
      table.insert(result, task)
    end
  end
  return result
end

function M.overdue()
  local now = os.time()
  local result = {}
  for _, task in ipairs(M.tasks) do
    if task.due_date and task.due_date < now and not task.completed then
      table.insert(result, task)
    end
  end
  return result
end

function M.stats()
  local total = #M.tasks
  local completed = 0
  local by_priority = { low = 0, medium = 0, high = 0, critical = 0 }
  for _, task in ipairs(M.tasks) do
    if task.completed then
      completed = completed + 1
    end
    if by_priority[task.priority] then
      by_priority[task.priority] = by_priority[task.priority] + 1
    end
  end
  return {
    total = total,
    completed = completed,
    pending = total - completed,
    by_priority = by_priority,
  }
end

return M
