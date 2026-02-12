if vim.g.loaded_claudecode then
  return
end
vim.g.loaded_claudecode = true

vim.api.nvim_create_user_command("Claude", function(args)
  if not require("claudecode").config then
    vim.notify("[claudecode] Plugin not configured. Call require('claudecode').setup() first.", vim.log.levels.WARN)
    return
  end
  if args.args == "" then
    require("claudecode.ui").toggle()
  else
    require("claudecode.chat").send(args.args)
  end
end, { nargs = "?", desc = "Claude Code" })
