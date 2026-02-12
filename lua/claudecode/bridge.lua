local M = {}

local job_id = nil
local event_handlers = {}
local buffer = ""

local function find_binary()
  local plugin_dir = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":h:h:h")
  local candidates = {
    plugin_dir .. "/rust/target/release/claudecode-bridge",
    plugin_dir .. "/lua/claudecode/bin/claudecode-bridge",
  }

  local uname = vim.uv.os_uname()
  local os_name = uname.sysname:lower()
  local arch = uname.machine
  if arch == "x86_64" then
    arch = "x86_64"
  elseif arch == "aarch64" or arch == "arm64" then
    arch = "aarch64"
  end
  table.insert(
    candidates,
    2,
    plugin_dir .. "/lua/claudecode/bin/claudecode-bridge-" .. os_name .. "-" .. arch
  )

  for _, path in ipairs(candidates) do
    if vim.fn.executable(path) == 1 then
      return path
    end
  end

  return nil
end

local function process_line(line)
  if line == "" then
    return
  end

  local ok, data = pcall(vim.json.decode, line)
  if not ok then
    return
  end

  for _, handler in ipairs(event_handlers) do
    handler(data)
  end
end

local function on_stdout(_, data, _)
  if not data then
    return
  end

  buffer = buffer .. table.concat(data, "\n")
  while true do
    local nl = buffer:find("\n")
    if not nl then
      break
    end
    local line = buffer:sub(1, nl - 1)
    buffer = buffer:sub(nl + 1)
    vim.schedule(function()
      process_line(line)
    end)
  end
end

local function on_exit(_, code, _)
  job_id = nil
  buffer = ""
  if code ~= 0 then
    vim.schedule(function()
      for _, handler in ipairs(event_handlers) do
        handler({ event = "error", message = "Bridge process exited with code " .. code })
      end
    end)
  end
end

function M.start(opts)
  if job_id then
    return true
  end

  local binary = (opts and opts.binary_path) or find_binary()
  if not binary then
    vim.notify("[claudecode] Bridge binary not found. Run :lua require('claudecode.build').install()", vim.log.levels.ERROR)
    return false
  end

  job_id = vim.fn.jobstart({ binary }, {
    on_stdout = on_stdout,
    on_exit = on_exit,
    stdout_buffered = false,
  })

  if job_id <= 0 then
    vim.notify("[claudecode] Failed to start bridge process", vim.log.levels.ERROR)
    job_id = nil
    return false
  end

  return true
end

function M.send(request)
  if not job_id then
    vim.notify("[claudecode] Bridge not running", vim.log.levels.WARN)
    return false
  end

  local json = vim.json.encode(request) .. "\n"
  vim.fn.chansend(job_id, json)
  return true
end

function M.on_event(callback)
  table.insert(event_handlers, callback)
end

function M.stop()
  if job_id then
    vim.fn.jobstop(job_id)
    job_id = nil
  end
  buffer = ""
end

function M.is_running()
  return job_id ~= nil
end

return M
