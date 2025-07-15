local M = {}

local command_utils = require('jj-nvim.jj.command_utils')

-- Abandon the specified commit
M.abandon_commit = function(commit, on_success)
  -- Validate commit
  local is_valid, err = command_utils.validate_commit(commit, { allow_root = false })
  if not is_valid then
    vim.notify(err, vim.log.levels.WARN)
    return false
  end

  local change_id, change_err = command_utils.get_change_id(commit)
  if not change_id then
    vim.notify(change_err, vim.log.levels.ERROR)
    return false
  end

  -- Confirm before abandoning
  local description = commit:get_short_description()
  local display_id = command_utils.get_short_display_id(commit, change_id)
  local confirm_msg = string.format("Abandon commit %s: %s?", display_id, description)

  command_utils.confirm_operation(confirm_msg, function(confirmed)
    if confirmed then
      local result, exec_err = command_utils.execute_with_error_handling({ 'abandon', change_id }, "abandon commit")
      if result then
        if on_success then on_success() end
        return true
      end
      return false
    end
  end, { cancel_message = "Abandon cancelled" })
end

-- Abandon multiple commits
M.abandon_multiple_commits = function(selected_commit_ids, on_success)
  -- Validate multiple commits
  local valid_commits, invalid_commits, err = command_utils.validate_multiple_commits(
    selected_commit_ids,
    { allow_root = false }
  )

  if err then
    vim.notify(err, vim.log.levels.WARN)
    return false
  end

  -- Report invalid commits
  if #invalid_commits > 0 then
    vim.notify(string.format("Cannot abandon: %s", table.concat(invalid_commits, ", ")), vim.log.levels.WARN)
    if #valid_commits == 0 then
      return false
    end
  end

  -- Confirm before abandoning
  local commit_count = #valid_commits
  local commit_summaries = command_utils.build_commit_summaries(valid_commits)
  local confirm_msg = string.format("Abandon %d commit%s?", commit_count, commit_count > 1 and "s" or "")
  if commit_summaries ~= "" then
    confirm_msg = confirm_msg .. "\n" .. commit_summaries
  end

  command_utils.confirm_operation(confirm_msg, function(confirmed)
    if confirmed then
      -- Get change IDs for all valid commits
      local change_ids = {}
      for _, commit in ipairs(valid_commits) do
        local change_id, change_err = command_utils.get_change_id(commit)
        if change_id then
          table.insert(change_ids, change_id)
        else
          vim.notify(string.format("Failed to get change ID for commit: %s", change_err), vim.log.levels.ERROR)
          return false
        end
      end

      vim.notify(string.format("Abandoning %d commit%s...", #change_ids, #change_ids > 1 and "s" or ""),
        vim.log.levels.INFO)

      -- Execute abandon command with all change IDs
      local cmd_args = { 'abandon' }
      for _, change_id in ipairs(change_ids) do
        table.insert(cmd_args, change_id)
      end

      local result, exec_err = command_utils.execute_with_error_handling(cmd_args, "abandon commits")
      if result then
        if on_success then on_success() end
        return true
      end
      return false
    end
  end, { cancel_message = "Abandon cancelled" })
end

-- Async version of abandon multiple commits
M.abandon_multiple_commits_async = function(selected_commit_ids, on_success)
  if not selected_commit_ids or #selected_commit_ids == 0 then
    vim.notify("No commits selected for abandoning", vim.log.levels.WARN)
    return
  end

  local change_ids = {}
  for _, commit_id in ipairs(selected_commit_ids) do
    table.insert(change_ids, commit_id)
  end

  local confirm_msg = string.format("Abandon %d commit(s)?", #change_ids)

  command_utils.confirm_operation(confirm_msg, function(confirmed)
    if confirmed then
      local cmd_args = { 'abandon' }
      for _, change_id in ipairs(change_ids) do
        table.insert(cmd_args, change_id)
      end

      -- Show progress indicator
      local timer = vim.loop.new_timer()
      local dots = ""
      local dot_count = 0

      timer:start(0, 1000, vim.schedule_wrap(function()
        dot_count = (dot_count + 1) % 4
        dots = string.rep(".", dot_count)
        vim.notify(string.format("Abandoning %d commit(s)%s", #change_ids, dots), vim.log.levels.INFO, { replace = true })
      end))

      command_utils.execute_with_error_handling_async(cmd_args, "abandon commits", {}, function(result, err)
        timer:stop()
        timer:close()

        if result then
          if on_success then on_success() end
        end
      end)
    end
  end, { cancel_message = "Abandon cancelled" })
end

return M

