local M = {}

M.pending = false
local listener_registered = false
local notified_streaming = false

local function register_listener()
  if listener_registered then
    return
  end
  listener_registered = true

  require("claudecode.bridge").on_event(function(data)
    if not M.pending or not data or not data.event then
      return
    end

    local evt = data.event

    if evt == "init" then
      vim.notify("[claudecode] Claude is thinking...", vim.log.levels.INFO)
    elseif evt == "text_chunk" and not notified_streaming then
      notified_streaming = true
      vim.notify("[claudecode] Claude is writing...", vim.log.levels.INFO)
    elseif evt == "tool_use" and data.tool == "Edit" then
      M.pending = false
      vim.notify("[claudecode] Applying edit...", vim.log.levels.INFO)
    elseif evt == "done" then
      M.pending = false
    elseif evt == "error" then
      M.pending = false
      vim.notify("[claudecode] Inline edit failed: " .. (data.message or "unknown error"), vim.log.levels.ERROR)
    end
  end)
end

function M.request(instruction, selection_info)
  if not instruction or instruction == "" then
    return
  end

  if not selection_info then
    vim.notify("[claudecode] No selection provided", vim.log.levels.WARN)
    return
  end

  if M.pending then
    vim.notify("[claudecode] An inline edit is already in progress", vim.log.levels.WARN)
    return
  end

  local bridge = require("claudecode.bridge")
  if not bridge.is_running() then
    if not bridge.start(require("claudecode").config) then
      return
    end
  end

  register_listener()

  local prompt = string.format(
    "Edit the following code in %s (lines %d-%d):\n\n```%s\n%s\n```\n\nInstruction: %s\n\nUse the Edit tool to make the change. Only modify the selected region.",
    selection_info.file_path,
    selection_info.start_line,
    selection_info.end_line,
    selection_info.filetype,
    selection_info.code,
    instruction
  )

  local system_prompt = "You are editing a specific code region selected by the user in their Neovim editor. "
    .. "Use the Edit tool with the exact old_string from the selected region and your new_string replacement. "
    .. "Only modify code within the selected lines. Do not add explanations."

  M.pending = true
  notified_streaming = false
  vim.notify("[claudecode] Sending to Claude...", vim.log.levels.INFO)

  bridge.send({
    method = "chat",
    params = {
      prompt = prompt,
      cwd = vim.fn.getcwd(),
      model = require("claudecode").config.model,
      allowed_tools = { "Edit" },
      append_system_prompt = system_prompt,
      permission_mode = "acceptEdits",
    },
  })
end

return M
