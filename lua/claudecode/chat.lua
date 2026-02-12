local M = {}

local ui = require("claudecode.ui")
local bridge = require("claudecode.bridge")
local ns = vim.api.nvim_create_namespace("claudecode_chat")

local streaming = false
local stream_line = nil
local current_session_id = nil

local function get_buf()
  return ui.get_chat_buf()
end

local function scroll_to_bottom()
  if not ui.is_open() then
    return
  end
  local win = ui.get_chat_win()
  local b = get_buf()
  if win and vim.api.nvim_win_is_valid(win) then
    local count = vim.api.nvim_buf_line_count(b)
    vim.api.nvim_win_set_cursor(win, { count, 0 })
  end
end

local function append_to_chat(lines)
  local b = get_buf()
  vim.bo[b].modifiable = true
  local count = vim.api.nvim_buf_line_count(b)
  vim.api.nvim_buf_set_lines(b, count, count, false, lines)
  vim.bo[b].modifiable = false
  scroll_to_bottom()
end

local function append_to_stream_line(text)
  local b = get_buf()
  if not stream_line then
    return
  end

  vim.bo[b].modifiable = true
  local lines = vim.api.nvim_buf_get_lines(b, stream_line, stream_line + 1, false)
  local current = lines[1] or ""
  local parts = vim.split(text, "\n", { plain = true })
  parts[1] = current .. parts[1]
  vim.api.nvim_buf_set_lines(b, stream_line, stream_line + 1, false, parts)
  vim.bo[b].modifiable = false

  stream_line = stream_line + #parts - 1
  scroll_to_bottom()
end

local function on_event(data)
  if not data or not data.event then
    return
  end

  local evt = data.event

  if evt == "init" then
    current_session_id = data.session_id
    if not current_session_id then
      append_to_chat({
        "",
        "--- " .. (data.model or "?") .. " ---",
        "",
      })
    end

  elseif evt == "text_chunk" then
    if not streaming then
      streaming = true
      local b = get_buf()
      vim.bo[b].modifiable = true
      local count = vim.api.nvim_buf_line_count(b)
      vim.api.nvim_buf_set_lines(b, count, count, false, { "" })
      vim.bo[b].modifiable = false
      stream_line = count
    end
    append_to_stream_line(data.text or "")

  elseif evt == "text" then
    streaming = false
    stream_line = nil

  elseif evt == "tool_use" then
    local tool = data.tool or "?"
    local summary = tool
    if data.input then
      if data.input.file_path then
        summary = summary .. ": " .. vim.fn.fnamemodify(data.input.file_path, ":t")
      elseif data.input.command then
        local cmd = data.input.command
        local cmd_max = require("claudecode").config.truncation.command
        if #cmd > cmd_max then
          cmd = cmd:sub(1, cmd_max - 3) .. "..."
        end
        summary = summary .. ": " .. cmd
      elseif data.input.pattern then
        summary = summary .. ": " .. data.input.pattern
      end
    end
    append_to_chat({ "", ">> " .. summary })

    if tool == "Edit" and data.input then
      require("claudecode.diff").show(data.id, data.input)
    end

  elseif evt == "tool_result" then
    local status = data.success and "ok" or "FAILED"
    local content = data.content or ""
    local result_max = require("claudecode").config.truncation.tool_result
    if #content > result_max then
      content = content:sub(1, result_max - 3) .. "..."
    end
    append_to_chat({ "   [" .. status .. "] " .. content })

  elseif evt == "cost" then
    local b = get_buf()
    local count = vim.api.nvim_buf_line_count(b)
    local target = math.max(count - 1, 0)
    local cost_str = string.format("$%.4f | %dms | %d in / %d out tokens",
      data.total_usd or 0,
      data.duration_ms or 0,
      data.input_tokens or 0,
      data.output_tokens or 0
    )
    pcall(vim.api.nvim_buf_set_extmark, b, ns, target, 0, {
      virt_text = { { cost_str, "Comment" } },
      virt_text_pos = "eol",
    })

  elseif evt == "done" then
    streaming = false
    stream_line = nil
    append_to_chat({ "", "---", "" })

  elseif evt == "error" then
    streaming = false
    stream_line = nil
    append_to_chat({ "", "[ERROR] " .. (data.message or "Unknown error"), "" })
  end
end

function M.setup()
  bridge.on_event(on_event)
end

function M.send(prompt, context)
  if not bridge.is_running() then
    if not bridge.start(require("claudecode").config) then
      return
    end
  end

  append_to_chat({ "", "> " .. prompt:gsub("\n", "\n> "), "" })

  if current_session_id then
    bridge.send({
      method = "continue",
      params = { prompt = prompt, context = context },
    })
  else
    bridge.send({
      method = "chat",
      params = {
        prompt = prompt,
        cwd = vim.fn.getcwd(),
        context = context,
        model = require("claudecode").config.model,
        allowed_tools = require("claudecode").config.allowed_tools,
        append_system_prompt = require("claudecode").config.append_system_prompt,
        permission_mode = require("claudecode").config.permission_mode,
      },
    })
  end
end

function M.resume(session_id)
  if not bridge.is_running() then
    if not bridge.start(require("claudecode").config) then
      return
    end
  end

  append_to_chat({ "[Resuming session " .. session_id .. "]" })

  bridge.send({
    method = "resume",
    params = {
      session_id = session_id,
      cwd = vim.fn.getcwd(),
    },
  })
end

function M.continue_chat(prompt)
  if not bridge.is_running() then
    vim.notify("[claudecode] No active session", vim.log.levels.WARN)
    return
  end

  bridge.send({
    method = "continue",
    params = { prompt = prompt },
  })
end

function M.new_session()
  current_session_id = nil
  append_to_chat({ "", "=== New Session ===", "" })
end

function M.abort()
  bridge.send({ method = "abort" })
  streaming = false
  stream_line = nil
  append_to_chat({ "", "[Aborted]", "" })
end

return M
