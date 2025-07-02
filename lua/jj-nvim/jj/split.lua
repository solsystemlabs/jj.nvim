local M = {}

local commands = require('jj-nvim.jj.commands')
local commit_utils = require('jj-nvim.core.commit')

-- Helper function to get change ID from commit
local function get_change_id(commit)
  if not commit then
    return nil, "No commit provided"
  end

  local change_id = commit_utils.get_id(commit)
  if not change_id or change_id == "" then
    return nil, "Invalid commit: missing change ID"
  end

  return change_id, nil
end

-- Helper function to get short display ID from commit
local function get_short_display_id(commit, change_id)
  return commit_utils.get_display_id(commit)
end

-- Interactive split
M.split_interactive = function(commit_id, options)
  options = options or {}
  local cmd_args = { 'split', '--interactive' }

  if commit_id and commit_id ~= "" then
    table.insert(cmd_args, '-r')
    table.insert(cmd_args, commit_id)
  end

  -- Add diff tool if specified
  if options.tool then
    table.insert(cmd_args, '--tool')
    table.insert(cmd_args, options.tool)
  end

  -- Add filesets/paths if specified
  if options.filesets and #options.filesets > 0 then
    for _, fileset in ipairs(options.filesets) do
      table.insert(cmd_args, fileset)
    end
  end

  return commands.execute_interactive_with_immutable_prompt(cmd_args, options)
end

-- Split source revision
M.split = function(source_revision, options)
  options = options or {}
  local cmd_args = { 'split' }

  -- Add source revision if provided, otherwise defaults to @
  if source_revision and source_revision ~= "" then
    table.insert(cmd_args, '-r')
    table.insert(cmd_args, source_revision)
  end

  -- Add message if provided
  if options.message and options.message ~= "" then
    table.insert(cmd_args, '-m')
    table.insert(cmd_args, options.message)
  end

  -- Add destination revisions if provided
  if options.destination and #options.destination > 0 then
    table.insert(cmd_args, '-d')
    for _, dest in ipairs(options.destination) do
      table.insert(cmd_args, dest)
    end
  end

  -- Add insert-after revisions if provided
  if options.insert_after and #options.insert_after > 0 then
    table.insert(cmd_args, '-A')
    for _, after in ipairs(options.insert_after) do
      table.insert(cmd_args, after)
    end
  end

  -- Add insert-before revisions if provided
  if options.insert_before and #options.insert_before > 0 then
    table.insert(cmd_args, '-B')
    for _, before in ipairs(options.insert_before) do
      table.insert(cmd_args, before)
    end
  end

  -- Add parallel flag if specified
  if options.parallel then
    table.insert(cmd_args, '--parallel')
  end

  -- Add interactive mode
  if options.interactive then
    table.insert(cmd_args, '--interactive')
  end

  -- Add diff tool for interactive mode
  if options.tool then
    table.insert(cmd_args, '--tool')
    table.insert(cmd_args, options.tool)
  end

  -- Add filesets/paths if specified
  if options.filesets and #options.filesets > 0 then
    for _, fileset in ipairs(options.filesets) do
      table.insert(cmd_args, fileset)
    end
  end

  -- Use interactive execution for interactive mode
  if options.interactive then
    -- Pass through callback options for interactive terminal
    local interactive_options = {
      on_success = options.on_success,
      on_error = options.on_error,
      on_cancel = options.on_cancel,
      cwd = options.cwd,
    }
    return commands.execute_interactive_with_immutable_prompt(cmd_args, interactive_options)
  else
    return commands.execute_with_immutable_prompt(cmd_args, { silent = options.silent })
  end
end

-- Split the specified commit
M.split_commit = function(commit, options)
  if not commit then
    vim.notify("No commit selected", vim.log.levels.WARN)
    return false
  end

  options = options or {}

  -- Don't allow splitting the root commit
  if commit.root then
    vim.notify("Cannot split the root commit", vim.log.levels.WARN)
    return false
  end

  local change_id, err = get_change_id(commit)
  if not change_id then
    vim.notify(err, vim.log.levels.ERROR)
    return false
  end

  local display_id = get_short_display_id(commit, change_id)

  -- Handle interactive mode with callbacks
  if options.interactive then
    -- Add callbacks for interactive mode
    options.on_success = function()
      vim.notify(string.format("Interactive split of %s completed", display_id), vim.log.levels.INFO)
      -- Buffer refresh is handled automatically by interactive terminal
    end
    options.on_error = function(exit_code)
      -- Error message already shown by interactive terminal
    end
    options.on_cancel = function()
      vim.notify("Interactive split cancelled", vim.log.levels.INFO)
    end

    -- Execute interactive split
    local success = M.split(change_id, options)
    if not success then
      vim.notify("Failed to start interactive split", vim.log.levels.ERROR)
      return false
    end
    return true -- Interactive command started successfully
  else
    -- Non-interactive split
    local result, exec_err = M.split(change_id, options)
    if not result then
      local error_msg = exec_err or "Unknown error"
      if error_msg:find("No such revision") then
        error_msg = "Commit not found - it may have been abandoned or modified"
      elseif error_msg:find("would create a cycle") then
        error_msg = "Cannot split - would create a cycle in commit graph"
      elseif error_msg:find("not in workspace") then
        error_msg = "Not in a jj workspace"
      elseif error_msg:find("empty commit") then
        error_msg = "Cannot split empty commit - use 'jj new' instead"
      end

      vim.notify(string.format("Failed to split commit: %s", error_msg), vim.log.levels.ERROR)
      return false
    end

    vim.notify(string.format("Split commit %s", display_id), vim.log.levels.INFO)
    return true
  end
end

-- Show split options menu
M.show_split_options_menu = function(target_commit, parent_win_id)
  local inline_menu = require('jj-nvim.ui.inline_menu')

  -- Determine target display name
  local target_display = ""
  if target_commit then
    target_display = target_commit.short_change_id or target_commit.change_id:sub(1, 8)
  else
    target_display = "@"
  end

  -- Define menu configuration
  local menu_config = {
    title = "Split " .. target_display,
    items = {
      {
        key = "q",
        description = "Quick split (interactive diff editor)",
        action = "quick_split",
      },
      {
        key = "i",
        description = "Interactive split (choose parts)",
        action = "interactive_split",
      },
      {
        key = "p",
        description = "Parallel split (side-by-side)",
        action = "parallel_split",
      },
      {
        key = "f",
        description = "Split specific files (filesets)",
        action = "fileset_split",
      },
      {
        key = "a",
        description = "Split with insert-after (select target)",
        action = "insert_after_split",
      },
      {
        key = "b",
        description = "Split with insert-before (select target)",
        action = "insert_before_split",
      },
      {
        key = "d",
        description = "Split with destination (select target)",
        action = "destination_split",
      },
    }
  }

  -- Show the menu
  parent_win_id = parent_win_id or vim.api.nvim_get_current_win()

  inline_menu.show(parent_win_id, menu_config, {
    on_select = function(selected_item)
      M.handle_split_options_selection(selected_item, target_commit)
    end,
    on_cancel = function()
      vim.notify("Split cancelled", vim.log.levels.INFO)
    end
  })
end

-- Handle split options menu selection
M.handle_split_options_selection = function(selected_item, target_commit)
  local options = {}

  -- Configure options based on selection
  if selected_item.action == "interactive_split" then
    options.interactive = true
  elseif selected_item.action == "parallel_split" then
    options.parallel = true
    options.interactive = true -- Parallel splits are typically interactive
  elseif selected_item.action == "fileset_split" then
    -- Prompt for filesets
    vim.ui.input({
      prompt = "Enter file patterns (e.g., '*.lua src/'):",
      default = "",
    }, function(filesets_str)
      if not filesets_str or filesets_str:match("^%s*$") then
        vim.notify("Split cancelled - no file patterns provided", vim.log.levels.INFO)
        return
      end

      -- Split filesets by spaces
      local filesets = vim.split(filesets_str, "%s+")
      options.filesets = filesets
      options.interactive = true -- Fileset splits are typically interactive

      local success = M.split_commit(target_commit, options)
      if success then
        -- Refresh buffer to show changes
        require('jj-nvim').refresh()
      end
    end)
    return -- Exit early for fileset handling
  elseif selected_item.action == "insert_after_split" then
    -- Enter target selection mode for insert-after
    local window = require('jj-nvim.ui.window')
    window.enter_split_target_selection_mode("insert_after", target_commit)
    return -- Exit early - target selection will handle the rest
  elseif selected_item.action == "insert_before_split" then
    -- Enter target selection mode for insert-before
    local window = require('jj-nvim.ui.window')
    window.enter_split_target_selection_mode("insert_before", target_commit)
    return -- Exit early - target selection will handle the rest
  elseif selected_item.action == "destination_split" then
    -- Enter target selection mode for destination
    local window = require('jj-nvim.ui.window')
    window.enter_split_target_selection_mode("destination", target_commit)
    return -- Exit early - target selection will handle the rest
  else
    -- quick_split uses default options (interactive diff editor)
    options.interactive = true
  end

  local success = M.split_commit(target_commit, options)
  if success then
    -- Refresh buffer to show changes
    require('jj-nvim').refresh()
  end
end

return M

