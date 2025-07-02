local M = {}

-- Setup common navigation keymaps used in both target selection and multi-select modes
M.setup_common_navigation = function(buf_id, win_id, navigation, opts, update_callback)
  local nav_opts = opts or {}
  local config = require('jj-nvim.config')
  
  -- Get navigation keys from config (with backward compatibility)
  local next_key = config.get_first_keybind('keybinds.log_window.navigation.next_commit') or 
                   config.get('keymaps.next_commit') or 'j'
  local prev_key = config.get_first_keybind('keybinds.log_window.navigation.prev_commit') or 
                   config.get('keymaps.prev_commit') or 'k'

  -- Basic navigation using configured keys
  vim.keymap.set('n', next_key, function()
    navigation.next_commit(win_id)
    if update_callback then update_callback() end
  end, nav_opts)

  vim.keymap.set('n', prev_key, function()
    navigation.prev_commit(win_id)
    if update_callback then update_callback() end
  end, nav_opts)

  -- Additional navigation (centered) - use configured keys
  local next_centered_key = config.get_first_keybind('keybinds.log_window.navigation.next_commit_centered') or 'J'
  local prev_centered_key = config.get_first_keybind('keybinds.log_window.navigation.prev_commit_centered') or 'K'
  
  vim.keymap.set('n', next_centered_key, function()
    navigation.next_commit_centered(win_id)
    if update_callback then update_callback() end
  end, nav_opts)

  vim.keymap.set('n', prev_centered_key, function()
    navigation.prev_commit_centered(win_id)
    if update_callback then update_callback() end
  end, nav_opts)

  -- Go to specific commits - use configured keys
  local goto_first_key = config.get_first_keybind('keybinds.log_window.navigation.goto_first') or 'gg'
  local goto_last_key = config.get_first_keybind('keybinds.log_window.navigation.goto_last') or 'G'
  local goto_current_key = config.get_first_keybind('keybinds.log_window.navigation.goto_current') or '@'
  
  vim.keymap.set('n', goto_first_key, function()
    navigation.goto_first_commit(win_id)
    if update_callback then update_callback() end
  end, nav_opts)

  vim.keymap.set('n', goto_last_key, function()
    navigation.goto_last_commit(win_id)
    if update_callback then update_callback() end
  end, nav_opts)

  vim.keymap.set('n', goto_current_key, function()
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
M.setup_main_keymaps = function(buf_id, win_id, state, actions, navigation, multi_select, buffer, window_utils, help,
                                config)
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

  -- Smart commit navigation using configured keys (with backward compatibility)
  local next_key = config.get_first_keybind('keybinds.log_window.navigation.next_commit') or 
                   config.get('keymaps.next_commit') or 'j'
  local prev_key = config.get_first_keybind('keybinds.log_window.navigation.prev_commit') or 
                   config.get('keymaps.prev_commit') or 'k'
  
  vim.keymap.set('n', next_key, function()
    navigation.next_commit(win_id)
  end, opts)
  vim.keymap.set('n', prev_key, function()
    navigation.prev_commit(win_id)
  end, opts)

  -- Additional navigation - use configured keys
  local next_centered_key = config.get_first_keybind('keybinds.log_window.navigation.next_commit_centered') or 'J'
  local prev_centered_key = config.get_first_keybind('keybinds.log_window.navigation.prev_commit_centered') or 'K'
  
  vim.keymap.set('n', next_centered_key, function()
    navigation.next_commit_centered(win_id)
  end, opts)
  vim.keymap.set('n', prev_centered_key, function()
    navigation.prev_commit_centered(win_id)
  end, opts)

  -- Go to specific commits - use configured keys
  local goto_first_key = config.get_first_keybind('keybinds.log_window.navigation.goto_first') or 'gg'
  local goto_last_key = config.get_first_keybind('keybinds.log_window.navigation.goto_last') or 'G'
  local goto_current_key = config.get_first_keybind('keybinds.log_window.navigation.goto_current') or '@'
  
  vim.keymap.set('n', goto_first_key, function()
    navigation.goto_first_commit(win_id)
  end, opts)
  vim.keymap.set('n', goto_last_key, function()
    navigation.goto_last_commit(win_id)
  end, opts)
  vim.keymap.set('n', goto_current_key, function()
    navigation.goto_current_commit(win_id)
  end, opts)

  -- Commit selection - use configured key
  local toggle_selection_key = config.get_first_keybind('keybinds.log_window.navigation.toggle_selection') or '<Space>'
  vim.keymap.set('n', toggle_selection_key, function()
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
  local config = require('jj-nvim.config')
  
  -- Show diff for current commit - use configured key (with backward compatibility)
  local show_diff_key = config.get_first_keybind('keybinds.log_window.actions.show_diff') or 
                        config.get('keymaps.show_diff') or '<CR>'
  vim.keymap.set('n', show_diff_key, function()
    local commit = navigation.get_current_commit(win_id)
    actions.show_diff(commit)
  end, opts)

  -- Show diff (alternative binding) - use configured key
  local show_diff_alt_key = config.get_first_keybind('keybinds.log_window.actions.show_diff_alt') or 'd'
  vim.keymap.set('n', show_diff_alt_key, function()
    local commit = navigation.get_current_commit(win_id)
    actions.show_diff(commit, 'git')
  end, opts)

  -- Show diff summary/stats - use configured key
  local show_diff_summary_key = config.get_first_keybind('keybinds.log_window.actions.show_diff_summary') or 'D'
  vim.keymap.set('n', show_diff_summary_key, function()
    local commit = navigation.get_current_commit(win_id)
    actions.show_diff_summary(commit)
  end, opts)

  -- Edit commit - use configured key (with backward compatibility)
  local edit_key = config.get_first_keybind('keybinds.log_window.actions.edit_message') or 
                   config.get('keymaps.edit_message') or 'e'
  vim.keymap.set('n', edit_key, function()
    local commit = navigation.get_current_commit(win_id)
    if actions.edit_commit(commit) then
      require('jj-nvim').refresh()
    end
  end, opts)

  -- Set description for commit - use configured key
  local set_description_key = config.get_first_keybind('keybinds.log_window.actions.set_description') or 'm'
  vim.keymap.set('n', set_description_key, function()
    local commit = navigation.get_current_commit(win_id)
    actions.set_description(commit, function()
      require('jj-nvim').refresh()
    end)
  end, opts)

  -- Abandon commit(s) - use configured key (with backward compatibility)
  local abandon_key = config.get_first_keybind('keybinds.log_window.actions.abandon') or 
                      config.get('keymaps.abandon') or 'a'
  vim.keymap.set('n', abandon_key, function()
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

  -- Explicit multi-abandon - use configured key
  local multi_abandon_key = config.get_first_keybind('keybinds.log_window.actions.multi_abandon') or 'A'
  vim.keymap.set('n', multi_abandon_key, function()
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

  -- Squash commit - use configured key (with backward compatibility)
  local squash_key = config.get_first_keybind('keybinds.log_window.actions.squash') or 
                     config.get('keymaps.squash') or 'x'
  vim.keymap.set('n', squash_key, function()
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

  -- Split commit - use configured key (with backward compatibility)
  local split_key = config.get_first_keybind('keybinds.log_window.actions.split') or 
                    config.get('keymaps.split') or 's'
  vim.keymap.set('n', split_key, function()
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

  -- Rebase commit - use configured key (with backward compatibility)
  local rebase_key = config.get_first_keybind('keybinds.log_window.actions.rebase') or 
                     config.get('keymaps.rebase') or 'r'
  vim.keymap.set('n', rebase_key, function()
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
M.setup_control_keymaps = function(buf_id, win_id, state, actions, navigation, multi_select, buffer, window_utils, help,
                                   config)
  local opts = { noremap = true, silent = true, buffer = buf_id }

  -- Clear all selections or close window - use configured key
  local clear_selections_key = config.get_first_keybind('keybinds.log_window.actions.clear_selections') or '<Esc>'
  vim.keymap.set('n', clear_selections_key, function()
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

  -- Toggle description expansion - use configured key
  local toggle_description_key = config.get_first_keybind('keybinds.log_window.actions.toggle_description') or '<Tab>'
  vim.keymap.set('n', toggle_description_key, function()
    local window_module = require('jj-nvim.ui.window')
    window_module.toggle_description_expansion()
  end, opts)

  -- New change creation (simple) - use configured key
  local new_change_key = config.get_first_keybind('keybinds.log_window.commit_operations.new_change') or 'n'
  vim.keymap.set('n', new_change_key, function()
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

  -- New change with options menu - use configured key
  local new_change_menu_key = config.get_first_keybind('keybinds.log_window.commit_operations.new_change_menu') or 'N'
  vim.keymap.set('n', new_change_menu_key, function()
    local window_module = require('jj-nvim.ui.window')
    window_module.show_new_change_menu()
  end, opts)

  -- Bookmark operations - use configured key
  local bookmarks_key = config.get_first_keybind('keybinds.log_window.window_controls.bookmarks') or 'b'
  vim.keymap.set('n', bookmarks_key, function()
    local window_module = require('jj-nvim.ui.window')
    window_module.show_bookmark_menu()
  end, opts)

  -- Buffer refresh - use configured key
  local refresh_key = config.get_first_keybind('keybinds.log_window.window_controls.refresh') or 'R'
  vim.keymap.set('n', refresh_key, function()
    vim.notify("Refreshing commits...", vim.log.levels.INFO)
    require('jj-nvim').refresh()
  end, opts)

  -- Window width adjustment keybinds - use configured keys
  local WIDTH_ADJUSTMENTS = { LARGE = 10, SMALL = 2 }
  local width_inc_large_key = config.get_first_keybind('keybinds.log_window.window_controls.width_increase_large') or '+'
  local width_dec_large_key = config.get_first_keybind('keybinds.log_window.window_controls.width_decrease_large') or '-'
  local width_inc_small_key = config.get_first_keybind('keybinds.log_window.window_controls.width_increase_small') or '='
  local width_dec_small_key = config.get_first_keybind('keybinds.log_window.window_controls.width_decrease_small') or '_'
  
  vim.keymap.set('n', width_inc_large_key, function()
    local window_module = require('jj-nvim.ui.window')
    window_module.adjust_width(WIDTH_ADJUSTMENTS.LARGE)
  end, opts)
  vim.keymap.set('n', width_dec_large_key, function()
    local window_module = require('jj-nvim.ui.window')
    window_module.adjust_width(-WIDTH_ADJUSTMENTS.LARGE)
  end, opts)
  vim.keymap.set('n', width_inc_small_key, function()
    local window_module = require('jj-nvim.ui.window')
    window_module.adjust_width(WIDTH_ADJUSTMENTS.SMALL)
  end, opts)
  vim.keymap.set('n', width_dec_small_key, function()
    local window_module = require('jj-nvim.ui.window')
    window_module.adjust_width(-WIDTH_ADJUSTMENTS.SMALL)
  end, opts)

  -- Git operations - use configured keys
  local fetch_key = config.get_first_keybind('keybinds.log_window.git_operations.fetch') or 'f'
  local push_key = config.get_first_keybind('keybinds.log_window.git_operations.push') or 'p'
  local show_status_key = config.get_first_keybind('keybinds.log_window.git_operations.show_status') or 'S'
  
  vim.keymap.set('n', fetch_key, function()
    if actions.git_fetch() then
      require('jj-nvim').refresh()
    end
  end, opts)

  vim.keymap.set('n', push_key, function()
    if actions.git_push() then
      require('jj-nvim').refresh()
    end
  end, opts)

  vim.keymap.set('n', show_status_key, function()
    actions.show_status()
  end, opts)

  -- Commit operations - use configured keys
  local quick_commit_key = config.get_first_keybind('keybinds.log_window.commit_operations.quick_commit') or 'c'
  local commit_menu_key = config.get_first_keybind('keybinds.log_window.commit_operations.commit_menu') or 'C'
  
  vim.keymap.set('n', quick_commit_key, function()
    actions.commit_working_copy({}, function()
      require('jj-nvim').refresh()
    end)
  end, opts)

  vim.keymap.set('n', commit_menu_key, function()
    actions.show_commit_menu(win_id)
  end, opts)

  -- Undo last operation - use configured key (with backward compatibility)
  local undo_key = config.get_first_keybind('keybinds.log_window.actions.undo') or 'u'
  vim.keymap.set('n', undo_key, function()
    if actions.undo_last(function()
          require('jj-nvim').refresh()
        end) then
      require('jj-nvim').refresh()
    end
  end, opts)

  -- Close window - use configured key (with backward compatibility)
  local close_key = config.get_first_keybind('keybinds.log_window.actions.close') or 
                    config.get('keymaps.close') or 'q'
  vim.keymap.set('n', close_key, function()
    local window_module = require('jj-nvim.ui.window')
    window_module.close()
  end, opts)

  -- Help dialog - use configured key
  local help_key = config.get_first_keybind('keybinds.log_window.actions.help') or '?'
  vim.keymap.set('n', help_key, function()
    help.show(win_id)
  end, opts)

  -- Revset operations - use configured keys
  local revset_menu_key = config.get_first_keybind('keybinds.log_window.revsets.show_menu') or 'rs'
  local revset_input_key = config.get_first_keybind('keybinds.log_window.revsets.custom_input') or 'rr'
  
  vim.keymap.set('n', revset_menu_key, function()
    require('jj-nvim').show_revset_menu()
  end, opts)

  vim.keymap.set('n', revset_input_key, function()
    local input = vim.fn.input('Enter revset: ', require('jj-nvim').get_current_revset())
    if input and input ~= '' then
      require('jj-nvim').set_revset(input)
    end
  end, opts)
end

-- Setup target selection mode keymaps
M.setup_target_selection_keymaps = function(buf_id, win_id, navigation, opts)
  local config = require('jj-nvim.config')
  
  -- Target selection keymaps - use configured keys
  local confirm_key = config.get_first_keybind('keybinds.log_window.special_modes.target_selection.confirm') or '<CR>'
  local cancel_key = config.get_first_keybind('keybinds.log_window.special_modes.target_selection.cancel') or '<Esc>'
  local bookmark_selection_key = config.get_first_keybind('keybinds.log_window.special_modes.target_selection.bookmark_selection') or 'b'
  
  vim.keymap.set('n', confirm_key, function()
    local window_module = require('jj-nvim.ui.window')
    window_module.confirm_target_selection()
  end, opts)
  vim.keymap.set('n', cancel_key, function()
    local window_module = require('jj-nvim.ui.window')
    window_module.cancel_target_selection()
  end, opts)

  -- Add bookmark selection for squash operations
  local window_module = require('jj-nvim.ui.window')
  local mode_data = select(2, window_module.get_mode())
  if mode_data and mode_data.action == "squash" then
    vim.keymap.set('n', bookmark_selection_key, function()
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

  -- Toggle commit selection using configured key
  local config = require('jj-nvim.config')
  local toggle_selection_key = config.get_first_keybind('keybinds.log_window.special_modes.multi_select.toggle_selection') or '<Space>'
  vim.keymap.set('n', toggle_selection_key, function()
    local window_module = require('jj-nvim.ui.window')
    window_module.toggle_commit_selection()
  end, opts)

  -- Confirm selection using configured key
  local confirm_key = config.get_first_keybind('keybinds.log_window.special_modes.multi_select.confirm') or '<CR>'
  vim.keymap.set('n', confirm_key, function()
    local window_module = require('jj-nvim.ui.window')
    window_module.confirm_multi_selection()
  end, opts)

  -- Cancel multi-select mode using configured key
  local cancel_key = config.get_first_keybind('keybinds.log_window.special_modes.multi_select.cancel') or '<Esc>'
  vim.keymap.set('n', cancel_key, function()
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
