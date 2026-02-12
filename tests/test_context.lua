local function test_format_file_context()
  local path = "/tmp/test.lua"
  local ft = "lua"
  local content = 'print("hello")'
  local result = string.format("File: %s (%s)\n```%s\n%s\n```", path, ft, ft, content)

  assert(result:find("File: /tmp/test.lua", 1, true), "contains file path")
  assert(result:find("(lua)", 1, true), "contains filetype")
  assert(result:find("```lua", 1, true), "contains code fence")
  assert(result:find('print("hello")', 1, true), "contains content")
  print("PASS: test_format_file_context")
end

local function test_format_selection_context()
  local path = "/tmp/test.lua"
  local start_line = 5
  local end_line = 10
  local ft = "lua"
  local content = "local x = 1\nlocal y = 2"
  local result = string.format(
    "File: %s (lines %d-%d, %s)\n```%s\n%s\n```",
    path, start_line, end_line, ft, ft, content
  )

  assert(result:find("lines 5-10", 1, true), "contains line range")
  assert(result:find("local x = 1", 1, true), "contains selection content")
  print("PASS: test_format_selection_context")
end

local function test_format_diagnostics()
  local path = "/tmp/test.lua"
  local diags = {
    { lnum = 4, severity = "ERROR", message = "undefined variable 'foo'" },
    { lnum = 10, severity = "WARN", message = "unused variable 'bar'" },
  }

  local lines = { "Diagnostics for " .. path .. ":" }
  for _, d in ipairs(diags) do
    table.insert(lines, string.format("  Line %d: [%s] %s", d.lnum + 1, d.severity, d.message))
  end
  local result = table.concat(lines, "\n")

  assert(result:find("Diagnostics for /tmp/test.lua", 1, true), "contains file path")
  assert(result:find("Line 5: [ERROR]", 1, true), "contains first diagnostic")
  assert(result:find("Line 11: [WARN]", 1, true), "contains second diagnostic")
  print("PASS: test_format_diagnostics")
end

local function test_gather_concatenation()
  local parts = {
    "File: /tmp/a.lua (lua)\n```lua\nlocal a = 1\n```",
    "Diagnostics for /tmp/a.lua:\n  Line 1: [WARN] unused",
  }
  local result = table.concat(parts, "\n\n")

  assert(result:find("File: /tmp/a.lua", 1, true), "contains file part")
  assert(result:find("Diagnostics for", 1, true), "contains diagnostics part")
  assert(result:find("\n\n", 1, true), "parts separated by blank line")
  print("PASS: test_gather_concatenation")
end

local function test_empty_gather()
  local parts = {}
  local result
  if #parts == 0 then
    result = nil
  else
    result = table.concat(parts, "\n\n")
  end
  assert(result == nil, "empty gather returns nil")
  print("PASS: test_empty_gather")
end

test_format_file_context()
test_format_selection_context()
test_format_diagnostics()
test_gather_concatenation()
test_empty_gather()

print("\nAll context tests passed!")
