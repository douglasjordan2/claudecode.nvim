local function test_json_serialization()
  local events = {
    {
      event = "init",
      session_id = "abc-123",
      model = "claude-sonnet-4-5-20250514",
      tools = { "Read", "Write", "Edit" },
    },
    {
      event = "text_chunk",
      text = "Hello, world!",
    },
    {
      event = "text",
      text = "Full response text here.",
    },
    {
      event = "tool_use",
      tool = "Edit",
      id = "toolu_123",
      input = { file_path = "/tmp/test.lua", old_string = "foo", new_string = "bar" },
    },
    {
      event = "tool_result",
      tool = "Edit",
      id = "toolu_123",
      success = true,
      content = "File edited successfully",
    },
    {
      event = "cost",
      total_usd = 0.0042,
      duration_ms = 1500,
      input_tokens = 100,
      output_tokens = 50,
    },
    {
      event = "done",
    },
    {
      event = "error",
      message = "Something went wrong",
    },
    {
      event = "status",
      active = true,
      session_id = "abc-123",
    },
  }

  for _, evt in ipairs(events) do
    local json = vim.json.encode(evt)
    assert(type(json) == "string", "serializes to string: " .. evt.event)

    local decoded = vim.json.decode(json)
    assert(decoded.event == evt.event, "event type roundtrips: " .. evt.event)

    if evt.session_id then
      assert(decoded.session_id == evt.session_id, "session_id roundtrips")
    end
    if evt.text then
      assert(decoded.text == evt.text, "text roundtrips")
    end
    if evt.tool then
      assert(decoded.tool == evt.tool, "tool roundtrips")
    end
    if evt.success ~= nil then
      assert(decoded.success == evt.success, "success roundtrips")
    end
    if evt.total_usd then
      assert(type(decoded.total_usd) == "number", "cost roundtrips as number")
    end

    print("  PASS: " .. evt.event)
  end
end

local function test_request_deserialization()
  local requests = {
    {
      json = '{"method":"chat","params":{"prompt":"hello","cwd":"/tmp"}}',
      expected_method = "chat",
    },
    {
      json = '{"method":"resume","params":{"session_id":"abc-123","cwd":"/tmp"}}',
      expected_method = "resume",
    },
    {
      json = '{"method":"continue","params":{"prompt":"next question"}}',
      expected_method = "continue",
    },
    {
      json = '{"method":"abort"}',
      expected_method = "abort",
    },
    {
      json = '{"method":"status"}',
      expected_method = "status",
    },
  }

  for _, req in ipairs(requests) do
    local decoded = vim.json.decode(req.json)
    assert(decoded.method == req.expected_method, "method parses: " .. req.expected_method)

    local re_encoded = vim.json.encode(decoded)
    local re_decoded = vim.json.decode(re_encoded)
    assert(re_decoded.method == req.expected_method, "method roundtrips: " .. req.expected_method)

    print("  PASS: " .. req.expected_method)
  end
end

local function test_json_line_format()
  local evt = { event = "done" }
  local json = vim.json.encode(evt)
  local line = json .. "\n"

  assert(line:sub(-1) == "\n", "ends with newline")
  assert(not line:find("\n", 1, true) or line:find("\n") == #line, "only one newline at end")

  local parsed = vim.json.decode(line:sub(1, -2))
  assert(parsed.event == "done", "parses without trailing newline")
  print("PASS: test_json_line_format")
end

print("Protocol serialization tests:")
test_json_serialization()
print("\nRequest deserialization tests:")
test_request_deserialization()
print("\nJSON-line format tests:")
test_json_line_format()

print("\nAll protocol tests passed!")
