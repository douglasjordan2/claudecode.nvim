local lualine_require = require("lualine_require")
local M = lualine_require.require("lualine.component"):extend()

local spinner_frames = { "⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏" }

local state_highlights = {
  idle = "Comment",
  thinking = "DiagnosticWarn",
  streaming = "DiagnosticOk",
  tool_use = "DiagnosticInfo",
  error = "DiagnosticError",
}

local timer = nil
local prev_active = false

local function start_timer()
  if timer then
    return
  end
  timer = vim.uv.new_timer()
  timer:start(0, 80, vim.schedule_wrap(function()
    require("lualine").refresh()
  end))
end

local function stop_timer()
  if not timer then
    return
  end
  timer:stop()
  timer:close()
  timer = nil
end

function M:init(options)
  M.super.init(self, options)

  self.state_hls = {}
  for state, hl_group in pairs(state_highlights) do
    self.state_hls[state] = self:create_hl(hl_group, state)
  end
end

function M:update_status()
  local ok, claudecode = pcall(require, "claudecode")
  if not ok then
    return ""
  end

  local state = claudecode.get_state()
  local icons = claudecode.config.statusline.icons
  local icon = icons[state] or icons.idle

  local hl = self:format_hl(self.state_hls[state] or self.state_hls.idle)

  local active = state ~= "idle" and state ~= "error"

  if active and not prev_active then
    start_timer()
  elseif not active and prev_active then
    stop_timer()
  end
  prev_active = active

  if active then
    local hrtime = vim.uv.hrtime
    local frame = spinner_frames[math.floor(hrtime() / (1e6 * 80)) % #spinner_frames + 1]
    return hl .. frame .. " " .. icon .. " Claude [" .. state .. "]"
  end

  if state == "error" then
    return hl .. icon .. " Claude [error]"
  end

  return hl .. icon .. " Claude"
end

return M
