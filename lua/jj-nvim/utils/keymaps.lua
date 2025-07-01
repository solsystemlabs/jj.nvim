local M = {}

-- Setup common navigation keymaps used in both target selection and multi-select modes
M.setup_common_navigation = function(buf_id, win_id, navigation, opts, update_callback)
  local nav_opts = opts or {}

  -- Basic j/k navigation
  vim.keymap.set('n', 'j', function()
    navigation.next_commit(win_id)
    if update_callback then update_callback() end
  end, nav_opts)

  vim.keymap.set('n', 'k', function()
    navigation.prev_commit(win_id)
    if update_callback then update_callback() end
  end, nav_opts)

  -- Additional navigation (centered)
  vim.keymap.set('n', 'J', function()
    navigation.next_commit_centered(win_id)
    if update_callback then update_callback() end
  end, nav_opts)

  vim.keymap.set('n', 'K', function()
    navigation.prev_commit_centered(win_id)
    if update_callback then update_callback() end
  end, nav_opts)

  -- Go to specific commits
  vim.keymap.set('n', 'gg', function()
    navigation.goto_first_commit(win_id)
    if update_callback then update_callback() end
  end, nav_opts)

  vim.keymap.set('n', 'G', function()
    navigation.goto_last_commit(win_id)
    if update_callback then update_callback() end
  end, nav_opts)

  vim.keymap.set('n', '@', function()
    navigation.goto_current_commit(win_id)
    if update_callback then update_callback() end
  end, nav_opts)
end

-- Setup common disabled action keymaps for special modes
M.setup_disabled_actions = function(buf_id, message, opts)
  local disabled_opts = opts or {}

  vim.keymap.set('n', 'q', function()
    vim.notify(message, vim.log.levels.INFO)
  end, disabled_opts)

  vim.keymap.set('n', 'n', function()
    vim.notify(message, vim.log.levels.INFO)
  end, disabled_opts)

  vim.keymap.set('n', 'e', function()
    vim.notify(message, vim.log.levels.INFO)
  end, disabled_opts)

  vim.keymap.set('n', 'a', function()
    vim.notify(message, vim.log.levels.INFO)
  end, disabled_opts)
end

-- Remove conflicting keymaps before setting up new mode
M.clear_conflicting_keymaps = function(buf_id)
  pcall(vim.keymap.del, 'n', '<CR>', { buffer = buf_id })
  pcall(vim.keymap.del, 'n', '<Esc>', { buffer = buf_id })
  pcall(vim.keymap.del, 'n', '<Space>', { buffer = buf_id })
end


-- Setup main window keymaps
M.setup_main_keymaps = function(buf_id, win_id, state, actions, navigation, multi_select, buffer, window_utils, help, config)
  local opts = { noremap = true, silent = true, buffer = buf_id }

  -- Navigation keymaps
  vim.keymap.set('n', '<Up>', function()
    local cursor = vim.api.nvim_win_get_cursor(win_id)
    local current_line = cursor[1]
    local window_width = window_utils.get_width(win_id)
    local status_height = buffer.get_status_height(window_width)

    if current_line > status_height + 1 then
      vim.api.nvim_win_set_cursor(win_id, { current_line - 1, 0 })
    end
  end, opts)

  vim.keymap.set('n', '<Down>', function()
    local cursor = vim.api.nvim_win_get_cursor(win_id)
    local current_line = cursor[1]
    local window_width = window_utils.get_width(win_id)
    local status_height = buffer.get_status_height(window_width)

    if current_line > status_height + 1 then
      vim.api.nvim_win_set_cursor(win_id, { current_line + 1, 0 })
    end
  end, opts)

  -- Smart commit navigation
  vim.keymap.set('n', 'j', function()
    navigation.next_commit(win_id)
  end, opts)
  vim.keymap.set('n', 'k', function()
    navigation.prev_commit(win_id)
  end, opts)

  -- Additional navigation
  vim.keymap.set('n', 'J', function()
    navigation.next_commit_centered(win_id)
  end, opts)
  vim.keymap.set('n', 'K', function()
    navigation.prev_commit_centered(win_id)
  end, opts)

  -- Go to specific commits
  vim.keymap.set('n', 'gg', function()
    navigation.goto_first_commit(win_id)
  end, opts)
  vim.keymap.set('n', 'G', function()
    navigation.goto_last_commit(win_id)
  end, opts)
  vim.keymap.set('n', '@', function()
    navigation.goto_current_commit(win_id)
  end, opts)

  -- Commit selection
  vim.keymap.set('n', '<Space>', function()
    local commit = navigation.get_current_commit(win_id)
    if commit then
      state.selected_commits = multi_select.toggle_commit_selection(commit, state.selected_commits)
      local window_module = require('jj-nvim.ui.window')
      window_module.highlight_current_commit()
      local window_width = window_utils.get_width(win_id)
      buffer.update_status(buf_id, {
        selected_count = #state.selected_commits
      }, window_width)
    else
      local window_width = window_utils.get_width(win_id)
      buffer.update_status(buf_id, {
        selected_count = 0
      }, window_width)
    end
  end, opts)

  return opts
end

-- Setup action keymaps
M.setup_action_keymaps = function(buf_id, win_id, state, actions, navigation, opts)
  -- Show diff for current commit
  vim.keymap.set('n', '<CR>', function()
    local commit = navigation.get_current_commit(win_id)
    actions.show_diff(commit)
  end, opts)

  -- Show diff (alternative binding)
  vim.keymap.set('n', 'd', function()
    local commit = navigation.get_current_commit(win_id)
    actions.show_diff(commit, 'git')
  end, opts)

  -- Show diff summary/stats
  vim.keymap.set('n', 'D', function()
    local commit = navigation.get_current_commit(win_id)
    actions.show_diff_summary(commit)
  end, opts)

  -- Edit commit
  vim.keymap.set('n', 'e', function()
    local commit = navigation.get_current_commit(win_id)
    if actions.edit_commit(commit) then
      require('jj-nvim').refresh()
    end
  end, opts)

  -- Set description for commit
  vim.keymap.set('n', 'm', function()
    local commit = navigation.get_current_commit(win_id)
    actions.set_description(commit, function()
      require('jj-nvim').refresh()
    end)
  end, opts)

  -- Abandon commit(s)
  vim.keymap.set('n', 'a', function()
    if #state.selected_commits > 0 then
      actions.abandon_multiple_commits(state.selected_commits, function()
        state.selected_commits = {}
        require('jj-nvim').refresh()
        local window_utils = require('jj-nvim.utils.window')
        local buffer = require('jj-nvim.ui.buffer')
        local window_width = window_utils.get_width(win_id)
        buffer.update_status(buf_id, {
          selected_count = #state.selected_commits
        }, window_width)
      end)
    else
      local commit = navigation.get_current_commit(win_id)
      if commit then
        actions.abandon_commit(commit, function()
          require('jj-nvim').refresh()
        end)
      else
        vim.notify("No commit under cursor to abandon", vim.log.levels.WARN)
      end
    end
  end, opts)

  -- Explicit multi-abandon
  vim.keymap.set('n', 'A', function()
    if #state.selected_commits > 0 then
      actions.abandon_multiple_commits(state.selected_commits, function()
        state.selected_commits = {}
        require('jj-nvim').refresh()
        local window_utils = require('jj-nvim.utils.window')
        local buffer = require('jj-nvim.ui.buffer')
        local window_width = window_utils.get_width(win_id)
        buffer.update_status(buf_id, {
          selected_count = #state.selected_commits
        }, window_width)
      end)
    else
      vim.notify("No commits selected for multi-abandon", vim.log.levels.WARN)
    end
  end, opts)

  -- Squash commit
  vim.keymap.set('n', 'x', function()
    local current_commit = navigation.get_current_commit(win_id)
    if not current_commit then
      vim.notify("No commit under cursor to squash", vim.log.levels.WARN)
      return
    end

    if current_commit.root then
      vim.notify("Cannot squash the root commit", vim.log.levels.WARN)
      return
    end

    local window_module = require('jj-nvim.ui.window')
    window_module.enter_target_selection_mode("squash", current_commit)
  end, opts)

  -- Split commit
  vim.keymap.set('n', 'v', function()
    local current_commit = navigation.get_current_commit(win_id)
    if not current_commit then
      vim.notify("No commit under cursor to split", vim.log.levels.WARN)
      return
    end

    if current_commit.root then
      vim.notify("Cannot split the root commit", vim.log.levels.WARN)
      return
    end

    actions.show_split_options_menu(current_commit, win_id)
  end, opts)

  -- Rebase commit
  vim.keymap.set('n', 'r', function()
    local current_commit = navigation.get_current_commit(win_id)
    if not current_commit then
      vim.notify("No commit under cursor to rebase", vim.log.levels.WARN)
      return
    end

    if current_commit.root then
      vim.notify("Cannot rebase the root commit", vim.log.levels.WARN)
      return
    end

    actions.show_rebase_options_menu(current_commit, win_id)
  end, opts)
end

-- Setup control keymaps (window, git operations, etc.)
M.setup_control_keymaps = function(buf_id, win_id, state, actions, navigation, multi_select, buffer, window_utils, help, config)
  local opts = { noremap = true, silent = true, buffer = buf_id }

  -- Show selection status
  vim.keymap.set('n', 's', function()
    local count = #state.selected_commits
    if count > 0 then
      vim.notify(string.format("%d commit%s selected", count, count > 1 and "s" or ""), vim.log.levels.INFO)
    else
      vim.notify("No commits selected", vim.log.levels.INFO)
    end
  end, opts)

  -- Clear all selections or close window
  vim.keymap.set('n', '<Esc>', function()
    local count = #state.selected_commits
    if count > 0 then
      state.selected_commits = multi_select.clear_all_selections()
      local window_module = require('jj-nvim.ui.window')
      window_module.highlight_current_commit()
      local window_width = window_utils.get_width(win_id)
      buffer.update_status(buf_id, {
        selected_count = #state.selected_commits
      }, window_width)
    else
      local window_module = require('jj-nvim.ui.window')
      window_module.close()
    end
  end, opts)

  -- Toggle description expansion
  vim.keymap.set('n', '<Tab>', function()
    local window_module = require('jj-nvim.ui.window')
    window_module.toggle_description_expansion()
  end, opts)

  -- New change creation (simple)
  vim.keymap.set('n', 'n', function()
    local current_commit = navigation.get_current_commit(win_id)
    if not current_commit then
      vim.notify("No commit found at cursor position", vim.log.levels.WARN)
      return
    end

    vim.ui.input({ prompt = "Change description (Enter for none): " }, function(description)
      if description == nil then
        return
      end

      local options = {}
      if description and description ~= "" then
        options.message = description
      end

      if actions.new_child(current_commit, options) then
        require('jj-nvim').refresh()
      end
    end)
  end, opts)

  -- New change with options menu
  vim.keymap.set('n', 'N', function()
    local window_module = require('jj-nvim.ui.window')
    window_module.show_new_change_menu()
  end, opts)

  -- Bookmark operations
  vim.keymap.set('n', 'b', function()
    local window_module = require('jj-nvim.ui.window')
    window_module.show_bookmark_menu()
  end, opts)

  -- Buffer refresh
  vim.keymap.set('n', 'R', function()
    vim.notify("Refreshing commits...", vim.log.levels.INFO)
    require('jj-nvim').refresh()
  end, opts)

  -- Window width adjustment keybinds
  local WIDTH_ADJUSTMENTS = { LARGE = 10, SMALL = 2 }
  vim.keymap.set('n', '+', function() 
    local window_module = require('jj-nvim.ui.window')
    window_module.adjust_width(WIDTH_ADJUSTMENTS.LARGE) 
  end, opts)
  vim.keymap.set('n', '-', function() 
    local window_module = require('jj-nvim.ui.window')
    window_module.adjust_width(-WIDTH_ADJUSTMENTS.LARGE) 
  end, opts)
  vim.keymap.set('n', '=', function() 
    local window_module = require('jj-nvim.ui.window')
    window_module.adjust_width(WIDTH_ADJUSTMENTS.SMALL) 
  end, opts)
  vim.keymap.set('n', '_', function() 
    local window_module = require('jj-nvim.ui.window')
    window_module.adjust_width(-WIDTH_ADJUSTMENTS.SMALL) 
  end, opts)

  -- Git operations
  vim.keymap.set('n', 'f', function()
    if actions.git_fetch() then
      require('jj-nvim').refresh()
    end
  end, opts)

  vim.keymap.set('n', 'p', function()
    if actions.git_push() then
      require('jj-nvim').refresh()
    end
  end, opts)

  -- Repository status
  vim.keymap.set('n', 'S', function()
    actions.show_status()
  end, opts)

  -- Commit working copy changes
  vim.keymap.set('n', 'c', function()
    actions.commit_working_copy({}, function()
      require('jj-nvim').refresh()
    end)
  end, opts)

  -- Commit with options menu
  vim.keymap.set('n', 'C', function()
    actions.show_commit_menu(win_id)
  end, opts)

  -- Undo last operation
  vim.keymap.set('n', 'u', function()
    if actions.undo_last(function()
      require('jj-nvim').refresh()
    end) then
      require('jj-nvim').refresh()
    end
  end, opts)

  -- Close window
  vim.keymap.set('n', 'q', function()
    local window_module = require('jj-nvim.ui.window')
    window_module.close()
  end, opts)

  -- Help dialog
  vim.keymap.set('n', '?', function()
    help.show(win_id)
  end, opts)

  -- Revset operations
  vim.keymap.set('n', 'rs', function()
    require('jj-nvim').show_revset_menu()
  end, opts)

  vim.keymap.set('n', 'rr', function()
    local input = vim.fn.input('Enter revset: ', require('jj-nvim').get_current_revset())
    if input and input ~= '' then
      require('jj-nvim').set_revset(input)
    end
  end, opts)
end

-- Setup target selection mode keymaps
M.setup_target_selection_keymaps = function(buf_id, win_id, navigation, opts)
  -- Override Enter and Escape for target selection
  vim.keymap.set('n', '<CR>', function() 
    local window_module = require('jj-nvim.ui.window')
    window_module.confirm_target_selection() 
  end, opts)
  vim.keymap.set('n', '<Esc>', function() 
    local window_module = require('jj-nvim.ui.window')
    window_module.cancel_target_selection() 
  end, opts)

  -- Add bookmark selection for squash operations
  local window_module = require('jj-nvim.ui.window')
  local mode_data = select(2, window_module.get_mode())
  if mode_data and mode_data.action == "squash" then
    vim.keymap.set('n', 'b', function() 
      window_module.show_squash_bookmark_selection() 
    end, opts)
  end

  -- Setup common navigation keymaps
  M.setup_common_navigation(buf_id, win_id, navigation, opts)

  -- Disable other actions during target selection
  M.setup_disabled_actions(buf_id, "Press Esc to cancel target selection", opts)
end

-- Setup multi-select mode keymaps
M.setup_multi_select_keymaps = function(buf_id, win_id, navigation, opts)
  -- First, explicitly remove conflicting keymaps
  M.clear_conflicting_keymaps(buf_id)

  -- Space to toggle commit selection
  vim.keymap.set('n', '<Space>', function() 
    local window_module = require('jj-nvim.ui.window')
    window_module.toggle_commit_selection() 
  end, opts)

  -- Enter to confirm selection and create merge commit
  vim.keymap.set('n', '<CR>', function() 
    local window_module = require('jj-nvim.ui.window')
    window_module.confirm_multi_selection() 
  end, opts)

  -- Escape to cancel multi-select mode
  vim.keymap.set('n', '<Esc>', function() 
    local window_module = require('jj-nvim.ui.window')
    window_module.cancel_multi_selection() 
  end, opts)

  -- Setup common navigation keymaps with update callback
  local window_module = require('jj-nvim.ui.window')
  M.setup_common_navigation(buf_id, win_id, navigation, opts, window_module.update_multi_select_display)

  -- Disable other actions during multi-select mode
  M.setup_disabled_actions(buf_id, "Press Esc to cancel multi-selection, Enter to confirm", opts)
end

return M

