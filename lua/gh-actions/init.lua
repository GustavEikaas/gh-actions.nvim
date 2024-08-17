local M = {}

local function action_setup()
  local commands = {
    list = require("gh-actions.list").list,
    run = require("gh-actions.run").run
  }

  vim.api.nvim_create_user_command('Actions',
    function(commandOpts)
      local subcommand = commandOpts.fargs[1]
      local func = commands[subcommand]
      if func then
        func()
      else
        print("Invalid subcommand:", subcommand)
      end
    end, {
      nargs = 1,
      complete = function()
        local completion = {}
        for key, _ in pairs(commands) do
          table.insert(completion, key)
        end
        return completion
      end,

    })
end

M.setup = function()
  action_setup()
end

return M
