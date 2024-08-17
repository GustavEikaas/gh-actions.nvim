local M = {}

local function dispatch(number, json, yaml_buf, on_success)
  local fields = {}
  for key, value in pairs(json.args) do
    table.insert(fields, string.format("--field '%s=%s'", key, value))
  end
  local parsed = table.concat(fields, " ")
  vim.notify("dispatching")
  local lines = {}
  local cmd = string.format("gh workflow run %s %s --ref %s", number, parsed, json.ref)
  vim.notify(cmd)
  vim.fn.jobstart(cmd, {
    stdout_buffered = true,
    on_stdout = function(_, data)
      for _, value in ipairs(data) do
        table.insert(lines, value)
      end
    end,
    on_stderr = function(_, data)
      for _, value in ipairs(data) do
        table.insert(lines, value)
      end
    end,
    on_exit = function(_, b)
      if b ~= 0 then
        local old_yaml = vim.api.nvim_buf_get_lines(yaml_buf, 0, -1, false)
        table.insert(lines, "")
        table.insert(lines, "Press <leader>c to view yaml")
        vim.api.nvim_buf_set_option(yaml_buf, 'modifiable', true)
        vim.api.nvim_buf_set_lines(yaml_buf, 0, -1, true, lines)
        vim.api.nvim_buf_set_option(yaml_buf, 'modifiable', false)

        vim.keymap.set('n', '<leader>c', function()
          vim.api.nvim_buf_set_option(yaml_buf, 'modifiable', true)
          vim.api.nvim_buf_set_lines(yaml_buf, 0, -1, true, old_yaml)
          vim.api.nvim_buf_set_option(yaml_buf, 'modifiable', false)
        end, { buffer = yaml_buf, noremap = true, silent = true })
      else
        on_success()
      end
    end
  })
end

local function get_branch_name()
  local command = "git rev-parse --abbrev-ref HEAD"
  local handle = io.popen(command)
  if handle == nil then
    error("Failed to execute command: " .. command)
  end
  local value = handle:read("l")
  handle:close()
  return value
end

local function create_run_buf()
  local run_buf = vim.api.nvim_create_buf(false, true)
  local width = math.floor(vim.o.columns / 2) - 2
  local height = 20

  local opts = {
    relative = "editor",
    width = width,
    height = height,
    col = width + 2,                              -- Start just after the first window
    row = math.floor((vim.o.lines - height) / 2), -- Centered vertically
    style = "minimal",
    border = "rounded"
  }

  local win = vim.api.nvim_open_win(run_buf, true, opts)

  return {
    win = win,
    run_buf = run_buf
  }
end

local function getDefaultBufferState(inputs)
  local lines = {}
  table.insert(lines, "{")
  table.insert(lines, string.format('  "ref": "%s",', get_branch_name()))
  table.insert(lines, '  "args": {')

  for i, value in ipairs(inputs) do
    local non_trail_comma = i == #inputs and "" or ","
    table.insert(lines, string.format('    "%s": ""%s', type(value) == "string" and value or " ", non_trail_comma))
  end
  table.insert(lines, "  }")
  table.insert(lines, "}")

  return lines
end

local function run_window(win, run_buf, number, yaml_buf, on_success, inputs)
  vim.api.nvim_buf_set_keymap(run_buf, 'n', 'q', '<cmd>lua vim.api.nvim_win_close(' .. win .. ', true)<CR>',
    { noremap = true, silent = true })
  vim.api.nvim_buf_set_lines(run_buf, 0, -1, false, getDefaultBufferState(inputs))
  vim.api.nvim_buf_set_option(run_buf, 'modifiable', true)

  vim.keymap.set('n', '<leader>r', function()
    local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
    local json = vim.fn.json_decode(table.concat(lines, ""))
    dispatch(number, json, yaml_buf, on_success)
  end, { buffer = run_buf, noremap = true, silent = true })
end


local function parse_inputs(yaml_string)
  local inputs = {}
  -- Pattern to match the input names (assumes inputs are indented with 6 spaces)
  for input in yaml_string:gmatch("\n%s%s%s%s%s%s([%w%-]+):") do
    table.insert(inputs, input)
  end
  return inputs
end


local function yaml_window(buf, number)
  local width = math.floor(vim.o.columns / 2) - 2
  local height = 20

  local opts = {
    relative = "editor",
    width = width,
    height = height,
    col = 1,                                      -- Start from the left edge
    row = math.floor((vim.o.lines - height) / 2), -- Centered vertically
    style = "minimal",
    border = "rounded"
  }

  local win = vim.api.nvim_open_win(buf, true, opts)
  vim.api.nvim_buf_set_keymap(buf, 'n', 'q', '<cmd>lua vim.api.nvim_win_close(' .. win .. ', true)<CR>',
    { noremap = true, silent = true })
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "loading yaml" })
  vim.api.nvim_buf_set_option(buf, 'modifiable', false)

  local lines = {}
  vim.fn.jobstart(string.format("gh workflow view %s --ref %s  --yaml", number, get_branch_name()), {
    stdout_buffered = true,
    on_stdout = function(_, data)
      for _, value in ipairs(data) do
        table.insert(lines, value)
      end
    end,
    on_stderr = function(_, data)
      for _, value in ipairs(data) do
        table.insert(lines, value)
      end
    end,
    on_exit = function(_, b)
      if b == 0 then
        vim.api.nvim_buf_set_option(buf, 'modifiable', true)
        vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
        vim.api.nvim_buf_set_option(buf, 'modifiable', false)
        -- check lines for workflow_dispatch:
        local yaml = table.concat(lines, "\n")
        local s = yaml:match("workflow_dispatch:")
        local ns_id = require("gh-actions.constants").ns_id
        if s ~= nil then
          --try parse inputs
          local inputs = parse_inputs(yaml)
          local run_float_window = create_run_buf()
          vim.api.nvim_buf_set_option(run_float_window.run_buf, "filetype", "json")
          local on_success = function()
            vim.api.nvim_buf_delete(buf, { force = true })
            vim.api.nvim_buf_delete(run_float_window.run_buf, { force = true })
            vim.api.nvim_win_close(run_float_window.win, true)
            vim.cmd("Actions list")
          end

          run_window(run_float_window.win, run_float_window.run_buf, number, buf, on_success, inputs)

          vim.api.nvim_buf_set_extmark(run_float_window.run_buf, ns_id, 0, 0, {
            virt_text = { { string.format("<leader>r to run"), "Character" } },
            virt_text_pos = "right_align",
            priority = 200,
          })

          vim.api.nvim_set_current_win(run_float_window.win)
        else
          vim.api.nvim_buf_set_extmark(buf, ns_id, 0, 0, {
            virt_text = { { string.format("This action does not support manual trigger"), "ErrorMsg" } },
            virt_text_pos = "right_align",
            priority = 200,
          })
        end
      else
        vim.api.nvim_buf_set_option(buf, 'modifiable', true)
        vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
        vim.api.nvim_buf_set_option(buf, 'modifiable', false)
      end
    end
  })
end

M.run = function()
  local buf_utils = require("gh-actions.render")
  local buf = buf_utils.createStdoutBuf()
  local lines = {}
  vim.fn.jobstart("gh workflow list", {
    stdout_buffered = true,
    on_stdout = function(_, data)
      for _, value in ipairs(data) do
        table.insert(lines, value)
      end
    end,
    on_stderr = function(_, data)
      for _, value in ipairs(data) do
        table.insert(lines, value)
      end
    end,
    on_exit = function(_, b)
      buf.write(lines)
      vim.notify("code " .. b)
    end
  })

  buf.write({ "Loading workflows..." })

  vim.keymap.set('n', '<leader>r', function()
    local line_num = vim.api.nvim_win_get_cursor(0)[1]
    local line = lines[line_num]
    local pattern = "(%w[%w%s]*)%s+(%w+)%s+(%d+)"
    local _, _, number = line:match(pattern)
    local yaml_buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_option(yaml_buf, "filetype", "yaml")
    yaml_window(yaml_buf, number)
  end, { buffer = buf.bufnr, noremap = true, silent = true })
end


return M
