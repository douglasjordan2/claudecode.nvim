local M = {}

M.config = {
  ui = {
    mode = "split",
    split_width = 80,
    float_width = 0.7,
    float_height = 0.8,
    border = "rounded",
    input_min_height = 2,
    input_max_height = 10,
  },
  truncation = {
    tool_result = 120,
    command = 60,
  },
  keymaps = {
    toggle = "<leader>cc",
    send = "<leader>cs",
    context = "<leader>cx",
    visual = "<leader>cv",
    abort = "<leader>ca",
    accept_diff = "<leader>cy",
    reject_diff = "<leader>cn",
    sessions = "<leader>cl",
  },
  model = nil,
  allowed_tools = nil,
  append_system_prompt = nil,
  permission_mode = nil,
  binary_path = nil,
}

local function deep_merge(base, override)
  local result = vim.deepcopy(base)
  for k, v in pairs(override) do
    if type(v) == "table" and type(result[k]) == "table" then
      result[k] = deep_merge(result[k], v)
    else
      result[k] = v
    end
  end
  return result
end

function M.setup(opts)
  opts = opts or {}
  M.config = deep_merge(M.config, opts)

  require("claudecode.chat").setup()
  require("claudecode.keymaps").setup(M.config)

  vim.api.nvim_create_user_command("Claude", function(args)
    if args.args == "" then
      require("claudecode.ui").toggle()
    else
      require("claudecode.chat").send(args.args)
    end
  end, { nargs = "?", desc = "Claude Code" })

  vim.api.nvim_create_user_command("ClaudeChat", function()
    require("claudecode.ui").focus_input()
  end, { desc = "Open Claude chat and focus input" })

  vim.api.nvim_create_user_command("ClaudeAbort", function()
    require("claudecode.chat").abort()
  end, { desc = "Abort Claude request" })

  vim.api.nvim_create_user_command("ClaudeSessions", function()
    require("claudecode.keymaps").session_picker()
  end, { desc = "List Claude sessions" })

  vim.api.nvim_create_user_command("ClaudeStatus", function()
    local bridge = require("claudecode.bridge")
    if bridge.is_running() then
      bridge.send({ method = "status" })
    else
      vim.notify("[claudecode] Bridge not running")
    end
  end, { desc = "Claude bridge status" })

  vim.api.nvim_create_user_command("ClaudeNew", function()
    require("claudecode.chat").new_session()
  end, { desc = "Start new Claude session" })
end

return M
