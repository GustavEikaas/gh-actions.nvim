local M = {}

local function parse_gh_timestamp(dateString)
  local pattern = "(%d+)-(%d+)-(%d+)T(%d+):(%d+):(%d+)Z"
  local year, month, day, hour, min, sec = dateString:match(pattern)
  return os.time({
    year = year,
    month = month,
    day = day,
    hour = hour,
    min = min,
    sec = sec,
    isdst = false
  })
end

local function time_ago(timestamp)
  local unix = parse_gh_timestamp(timestamp)
  local current_time = os.time(os.date("!*t"))
  local diff = current_time - unix

  if diff < 60 then
    return string.format("%d sec ago", diff)
  elseif diff < 3600 then
    return string.format("%d min ago", math.floor(diff / 60))
  elseif diff < 86400 then
    return string.format("%d hours ago", math.floor(diff / 3600))
  else
    return string.format("%d days ago", math.floor(diff / 86400))
  end
end

local fields =
"conclusion,createdAt,databaseId,displayTitle,event,headBranch,headSha,jobs,name,number,startedAt,status,updatedAt,url,workflowDatabaseId,workflowName"

local function get_job_status(status, conclusion)
  if status == "queued" then
    return "🕕"
  elseif status == "in_progress" then
    return "🔄"
  elseif conclusion == "success" then
    return "✔"
  elseif conclusion == "failure" then
    return "❌"
  elseif conclusion == "skipped" then
    return "⏩"
  else
    return "❓"
  end
end

local function get_step_status(status, conclusion)
  if status == "pending" then
    return "🕕"
  elseif status == "in_progress" then
    return "🔄"
  elseif conclusion == "success" then
    return "✔"
  elseif conclusion == "failure" then
    return "❌"
  elseif conclusion == "skipped" then
    return "⏩"
  else
    return "❓"
  end
end

local function get_workflow_status(status, conclusion)
  if status == "queued" then
    return "🕕"
  elseif status == "in_progress" then
    return "🔄"
  elseif conclusion == "success" then
    return "✔"
  elseif conclusion == "failure" then
    return "❌"
  elseif conclusion == "skipped" then
    return "⏩"
  else
    return "❓"
  end
end


local function get_job_details_lines(details)
  local lines = {}
  table.insert(lines,
    string.format("%s %s", details.displayTitle, get_workflow_status(details.status, details.conclusion)))

  table.insert(lines, "")

  table.insert(lines, string.format("Branch: %s", details.headBranch))
  table.insert(lines, string.format("Event: %s", details.event))
  if #details.conclusion > 0 then
    table.insert(lines, string.format("Finished: %s", time_ago(details.updatedAt)))
  elseif #details.startedAt > 0 then
    table.insert(lines, string.format("Started: %s", time_ago(details.startedAt)))
  end

  table.insert(lines, "")

  table.insert(lines, "Jobs:")
  for _, job in ipairs(details.jobs) do
    local jobIndent = "  "
    table.insert(lines, string.format("%sJob name: %s", jobIndent, job.name))
    table.insert(lines, string.format("%sStatus: %s", jobIndent, get_job_status(job.status, job.conclusion)))
    table.insert(lines, string.format("%sSteps: %s", jobIndent, ""))

    for i, step in ipairs(job.steps) do
      local stepIndent = jobIndent .. "       "
      table.insert(lines,
        string.format("%s%d. %s %s", stepIndent, i, step.name, get_step_status(step.status, step.conclusion)))
      if i ~= #job.steps then
        table.insert(lines, "")
      end
    end
  end

  return lines
end


local function job_stderr_float(id, float)
  local lines = {}
  vim.fn.jobstart(string.format("gh run view %s --log-failed", id), {
    stdout_buffered = true,
    on_stdout = function(_, data)
      for _, line in ipairs(data) do
        local pattern = "^(%w+)%s+(%w+)%s+([%d%-:T%.Z]+)%s+(.*)$"
        local job_name, step_name, timestamp, stderr = line:match(pattern)
        if job_name == nil then
          return
        end
        table.insert(lines, {
          job_name = job_name,
          step_name = step_name,
          timestamp = timestamp,
          stderr = stderr
        })
      end
    end,
    on_exit = function(_, b)
      local stderr = require("gh-actions.window").new_float():pos_right():on_win_close(function()
        float:pos_center()
      end):create()
      float:pos_left()

      float:on_win_close(function()
        if vim.api.nvim_win_is_valid(stderr.win) then
          vim.api.nvim_win_close(stderr.win, true)
        end
      end)

      local buf_lines = {}
      for _, value in ipairs(lines) do
        table.insert(buf_lines, string.format("%s: %s", value.step_name, value.stderr))
      end
      stderr:write_buf(buf_lines)

      for line_index, value in ipairs(lines) do
        vim.api.nvim_buf_add_highlight(stderr.buf, require("gh-actions.constants").ns_id, "ErrorMsg", line_index - 1,
          #value.step_name + 2, -1)
      end
    end
  })
end

local function update_job_details(id, float)
  local win = float.win
  local buf = float.buf

  local job_details = {}
  vim.fn.jobstart(string.format("gh run view %s --json %s", id, fields), {
    stdout_buffered = true,
    on_stdout = function(_, data)
      job_details = vim.fn.json_decode(table.concat(data, "\n"))
    end,
    on_exit = function(_, b)
      if b == 0 then
        float:write_buf(get_job_details_lines(job_details))
        vim.api.nvim_buf_add_highlight(buf, require("gh-actions.constants").ns_id, "Question", 0, 0, -1)

        vim.api.nvim_buf_add_highlight(buf, require("gh-actions.constants").ns_id, "Directory", 2, 0, -1)
        vim.api.nvim_buf_add_highlight(buf, require("gh-actions.constants").ns_id, "Directory", 3, 0, -1)
        vim.api.nvim_buf_add_highlight(buf, require("gh-actions.constants").ns_id, "Directory", 4, 0, -1)

        if job_details.conclusion == "failure" then
          job_stderr_float(id, float)
        end

        if #job_details.conclusion == 0 then
          local function s()
            if vim.api.nvim_win_is_valid(win) and vim.api.nvim_buf_is_valid(buf) then
              update_job_details(id)
            end
          end
          vim.defer_fn(s, 5000)
          vim.api.nvim_buf_set_extmark(buf, require("gh-actions.constants").ns_id, 0, 0, {
            virt_text = { { string.format("auto refresh enabled"), "Character" } },
            virt_text_pos = "right_align",
            priority = 200,
          })
        end
      else
        --stderr
      end
    end
  })
end

local function job_details_float(id)
  local float = require("gh-actions.window").new_float():create()
  float:write_buf({ "Loading job run.." })
  update_job_details(id, float)
end

local function populate_list(buf)
  local lines = {}
  vim.fn.jobstart("gh run list --json conclusion,displayTitle,event,headBranch,name,number,status,updatedAt,databaseId",
    {
      stdout_buffered = true,
      on_stdout = function(_, data)
        local json = vim.fn.json_decode(table.concat(data))
        for _, value in ipairs(json) do
          local wf_run = {
            status = value.status == "queued" and "🕐" or value.status == "in_progress" and "🔁" or
                value.conclusion == "failure" and "❌" or "✔ ",
            title = value.displayTitle,
            branch = value.headBranch,
            name = value.name,
            age = time_ago(value.updatedAt),
            id = value.databaseId
          }
          table.insert(lines, wf_run)
        end
      end,
      on_exit = function()
        local order = { "status", "title", "branch", "name", "age" }
        buf.write_table(lines, order)
        local ns_id = require("gh-actions.constants").ns_id
        vim.api.nvim_buf_set_extmark(buf.bufnr, ns_id, 0, 0, {
          virt_text = { { string.format("<leader>r to refresh"), "Character" } },
          virt_text_pos = "right_align",
          priority = 200,
        })
      end
    })
  vim.keymap.set('n', '<leader>o', function()
    local line_num = vim.api.nvim_win_get_cursor(0)[1]
    local id = lines[line_num - 2].id
    if id == nil then
      return
    end
    job_details_float(id)
  end, { buffer = buf.bufnr, noremap = true, silent = true })
end

M.list = function()
  local buf_name = "Workflow runs"
  local buf = require("gh-actions.render").createStdoutBuf(buf_name)
  populate_list(buf)
  vim.keymap.set('n', '<leader>r', function()
    vim.notify("Refreshing")
    populate_list(buf)
  end, { buffer = buf.bufnr, noremap = true, silent = true })
  buf.write({ "Loading actions..." })
end

return M
