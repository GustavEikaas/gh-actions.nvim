local M = {}

local function create_table_string(objects, order)
  if #objects == 0 then
    return { "No data available" }
  end

  local column_widths = {}
  for _, key in ipairs(order) do
    local max_length = #key
    for _, obj in ipairs(objects) do
      local value_length = #tostring(obj[key] or "")
      if value_length > max_length then
        max_length = value_length
      end
    end
    column_widths[key] = max_length + 5
  end

  local header = ""
  for _, key in ipairs(order) do
    header = header .. key .. string.rep(" ", column_widths[key] - #key + 2)
  end

  local separator = ""
  for _, key in ipairs(order) do
    separator = separator .. string.rep("-", column_widths[key] + 2)
  end

  local rows = {}
  for _, obj in ipairs(objects) do
    local row = ""
    for _, key in ipairs(order) do
      row = row .. tostring(obj[key] or "") .. string.rep(" ", column_widths[key] - #tostring(obj[key] or "") + 2)
    end
    table.insert(rows, row)
  end

  local result = { header, separator }
  for _, row in ipairs(rows) do
    table.insert(result, row)
  end

  return result
end

local function buffer_exists(name)
  local bufs = vim.api.nvim_list_bufs()
  for _, buf_id in ipairs(bufs) do
    if vim.api.nvim_buf_is_valid(buf_id) then
      local buf_name = vim.api.nvim_buf_get_name(buf_id)
      local buf_filename = vim.fn.fnamemodify(buf_name, ":t")
      if buf_filename == name then
        return buf_id
      end
    end
  end
  return nil
end

M.createStdoutBuf = function(name)
  local existing_buf = name == nil and nil or buffer_exists(name)
  local outBuf = existing_buf or vim.api.nvim_create_buf(true, true) -- false for not listing, true for scratch
  if existing_buf == nil and name ~= nil then
    vim.api.nvim_buf_set_name(outBuf, name)
  end
  vim.api.nvim_win_set_buf(0, outBuf)
  vim.api.nvim_set_current_buf(outBuf)
  vim.api.nvim_win_set_width(0, 30)
  vim.api.nvim_set_option_value("modifiable", false, { buf = outBuf })
  vim.api.nvim_set_option_value("filetype", "actions", { buf = outBuf })
  return {
    write = function(lines)
      vim.api.nvim_set_option_value("modifiable", true, { buf = outBuf })
      vim.api.nvim_buf_set_lines(outBuf, 0, -1, true, lines)
      vim.api.nvim_set_option_value("modifiable", false, { buf = outBuf })
    end,
    write_table = function(objects, order)
      local lines = create_table_string(objects, order)
      vim.api.nvim_set_option_value("modifiable", true, { buf = outBuf })
      vim.api.nvim_buf_set_lines(outBuf, 0, -1, true, lines)
      vim.api.nvim_set_option_value("modifiable", false, { buf = outBuf })
    end,
    bufnr = outBuf
  }
end

return M
