local M = {}

local inline_menu = require('jj-nvim.ui.inline_menu')
local navigation = require('jj-nvim.ui.navigation')
local actions = require('jj-nvim.jj.actions')
local command_utils = require('jj-nvim.jj.command_utils')
local config = require('jj-nvim.config')
local buffer = require('jj-nvim.ui.buffer')
local window_utils = require('jj-nvim.utils.window')

-- Get the current selected commits
local function get_selected_commits()
  local window_module = require('jj-nvim.ui.window')
  return window_module.get_selected_commits()
end

-- Generate menu items based on current selection state
local function generate_menu_items(win_id, current_commit, selected_commits)
  local items = {}
  local has_selections = selected_commits and #selected_commits > 0
  local single_selection = has_selections and #selected_commits == 1
  local multi_selection = has_selections and #selected_commits > 1
  
  -- Determine the target commit (selected or current)
  local target_commit = current_commit
  if single_selection then
    -- Find the selected commit
    local all_commits = command_utils.get_all_commits()
    if all_commits then
      for _, commit in ipairs(all_commits) do
        local commit_id = commit.change_id or commit.short_change_id
        if commit_id == selected_commits[1] then
          target_commit = commit
          break
        end
      end
    end
  end
  
  -- Context information for menu title
  local context = "No commit"
  if multi_selection then
    context = string.format("%d commits selected", #selected_commits)
  elseif single_selection then
    local display_id = command_utils.get_short_display_id(target_commit)
    context = string.format("1 commit selected (%s)", display_id)
  elseif current_commit then
    local display_id = command_utils.get_short_display_id(current_commit)
    context = string.format("Current commit (%s)", display_id)
  end
  
  -- Common single-commit actions
  if target_commit and not multi_selection then
    -- Diff operations
    table.insert(items, {
      key = "d",
      description = "Show diff",
      action = "show_diff",
      commit = target_commit
    })
    
    table.insert(items, {
      key = "D",
      description = "Show diff summary",
      action = "show_diff_summary", 
      commit = target_commit
    })
    
    -- Only allow certain operations on non-root commits
    if not target_commit.root then
      table.insert(items, {
        key = "e",
        description = "Edit commit",
        action = "edit_commit",
        commit = target_commit
      })
      
      table.insert(items, {
        key = "m",
        description = "Set description",
        action = "set_description",
        commit = target_commit
      })
      
      table.insert(items, {
        key = "a",
        description = "Abandon commit",
        action = "abandon_commit",
        commit = target_commit
      })
      
      table.insert(items, {
        key = "x",
        description = "Squash commit",
        action = "squash_commit",
        commit = target_commit
      })
      
      table.insert(items, {
        key = "X",
        description = "Squash into parent",
        action = "squash_into_parent",
        commit = target_commit
      })
      
      table.insert(items, {
        key = "s",
        description = "Split commit",
        action = "split_commit",
        commit = target_commit
      })
      
      table.insert(items, {
        key = "r",
        description = "Rebase commit",
        action = "rebase_commit",
        commit = target_commit
      })
    end
    
    -- New change operations
    table.insert(items, {
      key = "n",
      description = "New child change",
      action = "new_child",
      commit = target_commit
    })
  end
  
  -- Multi-commit actions
  if multi_selection then
    table.insert(items, {
      key = "a",
      description = "Abandon selected commits",
      action = "abandon_multiple",
      commit_ids = selected_commits
    })
    
    table.insert(items, {
      key = "r",
      description = "Rebase selected commits",
      action = "rebase_multiple",
      commit_ids = selected_commits
    })
  end
  
  -- Selection management
  if has_selections then
    table.insert(items, {
      key = "c",
      description = "Clear selections",
      action = "clear_selections"
    })
  end
  
  -- Global actions (always available)
  table.insert(items, {
    key = "R",
    description = "Refresh",
    action = "refresh"
  })
  
  table.insert(items, {
    key = "S",
    description = "Show status",
    action = "show_status"
  })
  
  table.insert(items, {
    key = "f",
    description = "Git fetch",
    action = "git_fetch"
  })
  
  table.insert(items, {
    key = "p",
    description = "Git push", 
    action = "git_push"
  })
  
  table.insert(items, {
    key = "u",
    description = "Undo last operation",
    action = "undo_last"
  })
  
  return items, context
end

-- Handle menu item selection
local function handle_menu_selection(item, win_id)
  local window_module = require('jj-nvim.ui.window')
  
  if item.action == "show_diff" then
    actions.show_diff(item.commit)
  elseif item.action == "show_diff_summary" then
    actions.show_diff_summary(item.commit)
  elseif item.action == "edit_commit" then
    if actions.edit_commit(item.commit) then
      require('jj-nvim').refresh()
    end
  elseif item.action == "set_description" then
    actions.set_description(item.commit, function()
      require('jj-nvim').refresh()
    end)
  elseif item.action == "abandon_commit" then
    actions.abandon_commit(item.commit, function()
      require('jj-nvim').refresh()
    end)
  elseif item.action == "abandon_multiple" then
    actions.abandon_multiple_commits_async(item.commit_ids, function()
      -- Clear selections will be handled by the window module
      require('jj-nvim').refresh()
    end)
  elseif item.action == "squash_commit" then
    if item.commit.root then
      vim.notify("Cannot squash the root commit", vim.log.levels.WARN)
      return
    end
    window_module.enter_target_selection_mode("squash", item.commit)
  elseif item.action == "squash_into_parent" then
    if item.commit.root then
      vim.notify("Cannot squash the root commit", vim.log.levels.WARN)
      return
    end
    
    -- Find parent commit
    if not item.commit.parents or #item.commit.parents == 0 then
      vim.notify("No parent commit found", vim.log.levels.WARN)
      return
    end
    
    if #item.commit.parents > 1 then
      vim.notify("Commit has multiple parents. Please use regular squash to select target.", vim.log.levels.WARN)
      return
    end
    
    -- Get all commits to find the parent
    local buffer_module = require('jj-nvim.ui.buffer')
    local all_commits = buffer_module.get_commits()
    local parent_id = item.commit.parents[1]
    local parent_commit = nil
    
    -- Find parent commit by ID
    for _, commit in ipairs(all_commits) do
      if commit.short_commit_id == parent_id or 
         commit.commit_id == parent_id or 
         commit.short_change_id == parent_id or
         commit.change_id == parent_id then
        parent_commit = commit
        break
      end
    end
    
    if not parent_commit then
      vim.notify("Parent commit not found in current view", vim.log.levels.WARN)
      return
    end
    
    -- Show squash options menu directly with parent as target
    local squash = require('jj-nvim.jj.squash')
    squash.show_squash_options_menu(parent_commit, "commit", win_id, item.commit)
  elseif item.action == "split_commit" then
    if item.commit.root then
      vim.notify("Cannot split the root commit", vim.log.levels.WARN)
      return
    end
    actions.show_split_options_menu(item.commit, win_id)
  elseif item.action == "rebase_commit" then
    if item.commit.root then
      vim.notify("Cannot rebase the root commit", vim.log.levels.WARN)
      return
    end
    actions.show_rebase_options_menu(item.commit, win_id)
  elseif item.action == "rebase_multiple" then
    actions.rebase_multiple_commits(item.commit_ids, function()
      -- Clear selections will be handled by the window module
      require('jj-nvim').refresh()
    end)
  elseif item.action == "new_child" then
    vim.ui.input({ prompt = "Change description (Enter for none): " }, function(description)
      if description == nil then
        return
      end
      
      local options = {}
      if description and description ~= "" then
        options.message = description
      end
      
      if actions.new_child(item.commit, options) then
        require('jj-nvim').refresh()
      end
    end)
  elseif item.action == "clear_selections" then
    -- This will be handled by implementing a clear_selections method in window module
    window_module.clear_selections()
    window_module.highlight_current_commit()
  elseif item.action == "refresh" then
    vim.notify("Refreshing commits...", vim.log.levels.INFO)
    require('jj-nvim').refresh()
  elseif item.action == "show_status" then
    actions.show_status()
  elseif item.action == "git_fetch" then
    actions.git_fetch_async({}, function(success)
      if success then
        require('jj-nvim').refresh()
      end
    end)
  elseif item.action == "git_push" then
    actions.git_push_async({}, function(success)
      if success then
        require('jj-nvim').refresh()
      end
    end)
  elseif item.action == "undo_last" then
    if actions.undo_last(function()
      require('jj-nvim').refresh()
    end) then
      require('jj-nvim').refresh()
    end
  else
    vim.notify("Unknown action: " .. (item.action or "nil"), vim.log.levels.WARN)
  end
end

-- Show the action menu
M.show = function(win_id)
  if not win_id or not vim.api.nvim_win_is_valid(win_id) then
    vim.notify("Invalid window", vim.log.levels.WARN)
    return
  end
  
  -- Get current context
  local current_commit = navigation.get_current_commit(win_id)
  local selected_commits = get_selected_commits()
  
  -- Generate menu items based on context
  local items, context = generate_menu_items(win_id, current_commit, selected_commits)
  
  if #items == 0 then
    vim.notify("No actions available", vim.log.levels.INFO)
    return
  end
  
  -- Create menu configuration
  local menu_config = {
    id = "action_menu",
    title = "Actions - " .. context,
    items = items
  }
  
  -- Show menu
  inline_menu.show(win_id, menu_config, {
    on_select = function(item)
      handle_menu_selection(item, win_id)
    end,
    on_cancel = function()
      -- Restore context window if it was shown before
      local context_window = require('jj-nvim.ui.context_window')
      if config.get('context_window.auto_show') then
        local current_commit = navigation.get_current_commit(win_id)
        local selected_commits = get_selected_commits()
        context_window.update(win_id, current_commit, selected_commits)
      end
    end
  })
end

return M