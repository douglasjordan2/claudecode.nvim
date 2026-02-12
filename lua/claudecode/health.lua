local M = {}

M.check = function()
  vim.health.start("claudecode.nvim")

  local nvim_version = vim.version()
  if nvim_version.major == 0 and nvim_version.minor < 10 then
    vim.health.error("Neovim 0.10+ required, found " .. tostring(nvim_version))
  else
    vim.health.ok("Neovim " .. tostring(nvim_version))
  end

  if vim.fn.executable("claude") == 1 then
    local result = vim.fn.system("claude --version 2>/dev/null")
    result = vim.trim(result)
    vim.health.ok("claude CLI: " .. result)
  else
    vim.health.error("claude CLI not found in PATH")
  end

  local bridge = require("claudecode.bridge")
  local plugin_dir = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":h:h:h")
  local binary_paths = {
    plugin_dir .. "/rust/target/release/claudecode-bridge",
    plugin_dir .. "/lua/claudecode/bin/claudecode-bridge",
  }

  local found_binary = false
  for _, path in ipairs(binary_paths) do
    if vim.fn.executable(path) == 1 then
      vim.health.ok("Bridge binary: " .. path)
      found_binary = true
      break
    end
  end

  if not found_binary then
    vim.health.error(
      "Bridge binary not found. Run :lua require('claudecode.build').install()",
      { "cd " .. plugin_dir .. "/rust && cargo build --release" }
    )
  end

  local api_key = vim.env.ANTHROPIC_API_KEY
  if api_key and api_key ~= "" then
    vim.health.ok("ANTHROPIC_API_KEY is set")
  else
    vim.health.info("ANTHROPIC_API_KEY not set (may use claude CLI's auth)")
  end

  if bridge.is_running() then
    vim.health.ok("Bridge process is running")
  else
    vim.health.info("Bridge process not started (starts on first use)")
  end
end

return M
