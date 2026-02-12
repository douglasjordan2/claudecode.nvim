local M = {}

local function get_platform()
  local uname = vim.uv.os_uname()
  local os_name = uname.sysname:lower()
  local arch = uname.machine

  if arch == "arm64" then
    arch = "aarch64"
  end

  return os_name, arch
end

local function get_plugin_dir()
  return vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":h")
end

function M.install()
  local plugin_dir = get_plugin_dir()
  local os_name, arch = get_platform()
  local bin_dir = plugin_dir .. "/lua/claudecode/bin"
  vim.fn.mkdir(bin_dir, "p")

  local binary_name = "claudecode-bridge-" .. os_name .. "-" .. arch
  local target_path = bin_dir .. "/claudecode-bridge"

  local repo = "douglasjordan2/claudecode.nvim"
  local release_url = "https://github.com/" .. repo .. "/releases/latest/download/" .. binary_name

  vim.notify("[claudecode] Attempting to download prebuilt binary...")

  local download_cmd = string.format("curl -fSL -o %s %s 2>&1", vim.fn.shellescape(target_path), release_url)
  local result = vim.fn.system(download_cmd)

  if vim.v.shell_error == 0 then
    vim.fn.system("chmod +x " .. vim.fn.shellescape(target_path))
    vim.notify("[claudecode] Binary installed: " .. target_path)
    return true
  end

  vim.notify("[claudecode] Prebuilt binary not available, building from source...")

  if vim.fn.executable("cargo") ~= 1 then
    vim.notify("[claudecode] cargo not found. Install Rust: https://rustup.rs", vim.log.levels.ERROR)
    return false
  end

  local rust_dir = plugin_dir .. "/rust"
  local build_result = vim.fn.system("cd " .. vim.fn.shellescape(rust_dir) .. " && cargo build --release 2>&1")

  if vim.v.shell_error ~= 0 then
    vim.notify("[claudecode] Build failed:\n" .. build_result, vim.log.levels.ERROR)
    return false
  end

  local built_binary = rust_dir .. "/target/release/claudecode-bridge"
  if vim.fn.filereadable(built_binary) == 1 then
    vim.fn.system(string.format("cp %s %s", vim.fn.shellescape(built_binary), vim.fn.shellescape(target_path)))
    vim.fn.system("chmod +x " .. vim.fn.shellescape(target_path))
    vim.notify("[claudecode] Binary built and installed: " .. target_path)
    return true
  end

  vim.notify("[claudecode] Build succeeded but binary not found", vim.log.levels.ERROR)
  return false
end

return M
