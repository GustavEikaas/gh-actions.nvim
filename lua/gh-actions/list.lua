local M = {}

local function populateList(buf)
  local lines = {}
  vim.fn.jobstart("gh run list --json conclusion,displayTitle,event,headBranch,name,number,status", {
    stdout_buffered = true,
    on_stdout = function(_, data)
      local json = vim.fn.json_decode(table.concat(data))
      for _, value in ipairs(json) do
        local wf_run = {
          status = value.status == "queued" and "🕐" or value.conclusion == "failure" and "❌" or "✔ ",
          title = value.displayTitle,
          branch = value.headBranch,
          name = value.name
        }
        table.insert(lines, wf_run)
      end
    end,
    on_exit = function()
      local order = { "status", "title", "branch", "name" }
      buf.write_table(lines, order)
      local ns_id = require("gh-actions.constants").ns_id
      vim.api.nvim_buf_set_extmark(buf.bufnr, ns_id, 0, 0, {
        virt_text = { { string.format("<leader>r to refresh"), "Character" } },
        virt_text_pos = "right_align",
        priority = 200,
      })
    end
  })
end

M.list = function()
  local buf = require("gh-actions.render").createStdoutBuf()
  vim.api.nvim_buf_set_name(buf.bufnr, "Workflow runs")
  populateList(buf)
  vim.keymap.set('n', '<leader>r', function()
    vim.notify("Refreshing")
    populateList(buf)
  end, { buffer = buf.bufnr, noremap = true, silent = true })
  buf.write({ "Loading actions..." })
end

return M
