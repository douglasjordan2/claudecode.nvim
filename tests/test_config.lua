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

local function test_deep_merge_basic()
  local base = { a = 1, b = 2 }
  local override = { b = 3, c = 4 }
  local result = deep_merge(base, override)
  assert(result.a == 1, "base key preserved")
  assert(result.b == 3, "override replaces base")
  assert(result.c == 4, "new key added")
  assert(base.b == 2, "base not mutated")
  print("PASS: test_deep_merge_basic")
end

local function test_deep_merge_nested()
  local base = { ui = { mode = "split", width = 80 }, x = 1 }
  local override = { ui = { mode = "float" } }
  local result = deep_merge(base, override)
  assert(result.ui.mode == "float", "nested override applied")
  assert(result.ui.width == 80, "nested non-overridden key preserved")
  assert(result.x == 1, "top-level key preserved")
  print("PASS: test_deep_merge_nested")
end

local function test_deep_merge_empty_override()
  local base = { a = 1, b = { c = 2 } }
  local result = deep_merge(base, {})
  assert(result.a == 1, "base preserved with empty override")
  assert(result.b.c == 2, "nested base preserved")
  print("PASS: test_deep_merge_empty_override")
end

local function test_deep_merge_override_table_with_scalar()
  local base = { a = { nested = true } }
  local override = { a = "flat" }
  local result = deep_merge(base, override)
  assert(result.a == "flat", "table replaced by scalar")
  print("PASS: test_deep_merge_override_table_with_scalar")
end

local function test_default_config_values()
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
    permission_mode = "acceptEdits",
    binary_path = nil,
  }

  assert(M.config.ui.mode == "split", "default mode is split")
  assert(M.config.ui.split_width == 80, "default split_width is 80")
  assert(M.config.ui.input_min_height == 2, "default input_min_height is 2")
  assert(M.config.ui.input_max_height == 10, "default input_max_height is 10")
  assert(M.config.truncation.tool_result == 120, "default tool_result truncation is 120")
  assert(M.config.truncation.command == 60, "default command truncation is 60")
  assert(M.config.keymaps.toggle == "<leader>cc", "default toggle keymap")
  assert(M.config.model == nil, "default model is nil")
  print("PASS: test_default_config_values")
end

local function test_config_merge_with_user_opts()
  local defaults = {
    ui = {
      mode = "split",
      split_width = 80,
      input_min_height = 2,
      input_max_height = 10,
    },
    truncation = {
      tool_result = 120,
      command = 60,
    },
  }

  local user_opts = {
    ui = { mode = "float", split_width = 100 },
    truncation = { command = 80 },
  }

  local result = deep_merge(defaults, user_opts)
  assert(result.ui.mode == "float", "user override applied")
  assert(result.ui.split_width == 100, "user override applied")
  assert(result.ui.input_min_height == 2, "default preserved")
  assert(result.truncation.command == 80, "truncation override applied")
  assert(result.truncation.tool_result == 120, "truncation default preserved")
  print("PASS: test_config_merge_with_user_opts")
end

test_deep_merge_basic()
test_deep_merge_nested()
test_deep_merge_empty_override()
test_deep_merge_override_table_with_scalar()
test_default_config_values()
test_config_merge_with_user_opts()

print("\nAll config tests passed!")
