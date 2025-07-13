local M = {}

local config = require('jj-nvim.config')
local buffer = require('jj-nvim.ui.buffer')
local navigation = require('jj-nvim.ui.navigation')
local themes = require('jj-nvim.ui.themes')
local actions = require('jj-nvim.jj.actions')
local bookmark_commands = require('jj-nvim.jj.bookmark_commands')
local inline_menu = require('jj-nvim.ui.inline_menu')
local multi_select = require('jj-nvim.ui.multi_select')
local validation = require('jj-nvim.utils.validation')
local window_utils = require('jj-nvim.utils.window')
local keymaps = require('jj-nvim.utils.keymaps')
local commit_utils = require('jj-nvim.core.commit')
local help = require('jj-nvim.ui.help')

-- Constants
local WINDOW_CONSTRAINTS = {
  MIN_WIDTH = 30,
  MAX_WIDTH = 200,
}

local WIDTH_ADJUSTMENTS = {
  SMALL = 1,
  LARGE = 5,
}

-- Window modes for different interaction states
local MODES = {
  NORMAL = 'normal',               -- Standard log browsing mode
  NEW_MENU = 'new_menu',           -- New change creation menu mode
  TARGET_SELECT = 'target_select', -- Target selection mode for new changes
  MULTI_SELECT = 'multi_select',   -- Multi-parent selection mode
}

-- View types for unified selection system
local VIEW_TYPES = {
  LOG = 'log',         -- Standard commit log view
  BOOKMARK = 'bookmark' -- Bookmark list view
}

local state = {
  win_id = nil,
  buf_id = nil,
  mode = MODES.NORMAL,
  mode_data = {},        -- Mode-specific data storage
  selected_commits = {}, -- For multi-select mode (includes bookmark target commits)
  menu_stack = {},       -- Stack to track menu navigation history
  current_view = VIEW_TYPES.LOG, -- Current view type (log or bookmark)
  view_toggle_enabled = false, -- Whether view toggling is currently allowed
}

-- Menu stack management
local function push_menu(menu_info)
  table.insert(state.menu_stack, menu_info)
end

local function pop_menu()
  return table.remove(state.menu_stack)
end

local function get_previous_menu()
  return state.menu_stack[#state.menu_stack]
end

local function clear_menu_stack()
  state.menu_stack = {}
end

-- Central function to show bookmark selection menu with proper navigation
local function show_bookmark_selection_with_navigation(options, parent_menu_info)
  -- Push parent menu to stack if provided
  if parent_menu_info then
    push_menu(parent_menu_info)
  end

  -- Add navigation callbacks to options
  local enhanced_options = vim.tbl_deep_extend("force", options, {
    parent_menu_callback = function()
      local prev_menu = pop_menu()
      if prev_menu then
        vim.schedule(function()
          if prev_menu.type == "bookmark_operations" then
            M.show_bookmark_menu()
          else
            -- Default fallback - clear stack
            clear_menu_stack()
          end
        end)
      else
        clear_menu_stack()
      end
    end,
    on_cancel = function()
      clear_menu_stack()
    end
  })

  return M.show_bookmark_selection_menu(enhanced_options)
end

-- Universal function to show any menu with proper navigation
local function show_menu_with_navigation(menu_func, menu_config, callbacks, parent_menu_info)
  -- Push parent menu to stack if provided
  if parent_menu_info then
    push_menu(parent_menu_info)
  end

  -- Enhance callbacks with navigation
  local enhanced_callbacks = vim.tbl_deep_extend("force", callbacks or {}, {
    parent_menu_callback = function()
      local prev_menu = pop_menu()
      if prev_menu then
        vim.schedule(function()
          -- Route back to appropriate parent menu based on type
          if prev_menu.type == "bookmark_operations" then
            M.show_bookmark_menu()
          elseif prev_menu.type == "bookmark_selection" then
            M.show_bookmark_selection_menu(prev_menu.options or {})
          else
            -- Default fallback - clear stack
            clear_menu_stack()
          end
        end)
      else
        clear_menu_stack()
      end
    end,
    on_cancel = function()
      -- Call original on_cancel if it exists, then clear stack
      if callbacks and callbacks.on_cancel then
        callbacks.on_cancel()
      end
      clear_menu_stack()
    end
  })

  return menu_func(menu_config, enhanced_callbacks)
end


-- Helper function to create window (using split instead of floating)
local function create_window()
  local width = config.get_window_width()
  local position = config.get('window.position')

  -- Create a vertical split
  if position == 'left' then
    -- For left position, create split at the leftmost edge
    vim.cmd('topleft vsplit')
  else
    -- For right position, create split at the rightmost edge
    vim.cmd('botright vsplit')
  end

  -- Get the new window and resize it
  local win_id = vim.api.nvim_get_current_win()
  vim.api.nvim_win_set_width(win_id, width)

  return win_id
end

-- Helper function to configure window and buffer display options
local function setup_window_display()
  vim.api.nvim_win_set_option(state.win_id, 'wrap', false)       -- Disable wrapping to debug
  vim.api.nvim_win_set_option(state.win_id, 'cursorline', false) -- Disable cursorline to prevent gutter highlighting

  -- Disable line numbers and gutter
  vim.api.nvim_win_set_option(state.win_id, 'number', false)
  vim.api.nvim_win_set_option(state.win_id, 'relativenumber', false)
  vim.api.nvim_win_set_option(state.win_id, 'signcolumn', 'no')

  -- Remove tilde column for empty lines and disable whitespace dots
  vim.api.nvim_win_set_option(state.win_id, 'fillchars', 'eob: ')
  vim.api.nvim_win_set_option(state.win_id, 'list', false)

  -- Ensure buffer supports colors
  vim.api.nvim_buf_set_option(state.buf_id, 'syntax', 'off')
  vim.api.nvim_set_option_value('termguicolors', true, {})

  -- Set up commit highlighting
  M.setup_commit_highlighting()

  M.setup_keymaps()
end

M.is_open = function()
  return state.win_id ~= nil and vim.api.nvim_win_is_valid(state.win_id)
end

M.open = function(content)
  if M.is_open() then
    return
  end

  -- Clear selections on window open
  state.selected_commits = {}

  state.buf_id = buffer.create(content)
  state.win_id = create_window()
  vim.api.nvim_win_set_buf(state.win_id, state.buf_id)

  setup_window_display()
end

-- Open window with an existing buffer (for commit-based system)
M.open_with_buffer = function(buf_id)
  if M.is_open() then
    return
  end

  -- Clear selections on window open
  state.selected_commits = {}

  state.buf_id = buf_id
  state.win_id = create_window()
  vim.api.nvim_win_set_buf(state.win_id, state.buf_id)

  setup_window_display()

  -- Initialize status display and cursor position
  local window_width = window_utils.get_width(state.win_id)

  -- Find the current working copy commit
  local commits = buffer.get_commits()
  local current_working_copy_id = nil
  if commits then
    for _, commit in ipairs(commits) do
      if commit.current_working_copy then
        current_working_copy_id = commit.short_change_id or commit.change_id
        break
      end
    end
  end

  buffer.update_status(state.buf_id, {
    selected_count = 0,
    current_mode = state.mode,
    current_commit_id = current_working_copy_id,
    repository_info = "Repository: jj"
  }, window_width)

  -- Position cursor at first commit (after status lines)
  -- We need to do this after the buffer is fully updated with status
  vim.schedule(function()
    if state.win_id and vim.api.nvim_win_is_valid(state.win_id) then
      local status_height = buffer.get_status_height(window_width)
      -- Position at first line after status box
      vim.api.nvim_win_set_cursor(state.win_id, { status_height + 1, 0 })
    end
  end)
end

M.close = function()
  -- Close context window first
  local context_window = require('jj-nvim.ui.context_window')
  context_window.close()
  
  if state.win_id and vim.api.nvim_win_is_valid(state.win_id) then
    vim.api.nvim_win_close(state.win_id, false)
  end

  -- Clear selections on window close
  state.selected_commits = {}

  state.win_id = nil
  state.buf_id = nil
end

M.setup_keymaps = function()
  if not state.buf_id then return end

  -- Clear potential old keymaps first (navigation and actions)
  local possible_nav_keys = {'j', 'k', 'h', 'l'}
  local possible_action_keys = {'a', 'o', 'e', 'r', 'x', 's', 'q', 'u', '<CR>'}
  
  for _, key in ipairs(possible_nav_keys) do
    pcall(vim.keymap.del, 'n', key, { buffer = state.buf_id })
  end
  
  for _, key in ipairs(possible_action_keys) do
    pcall(vim.keymap.del, 'n', key, { buffer = state.buf_id })
  end

  -- Use consolidated keymaps from keymaps.lua
  local opts = keymaps.setup_main_keymaps(
    state.buf_id, state.win_id, state, actions, navigation, 
    multi_select, buffer, window_utils, help, config
  )
  
  keymaps.setup_action_keymaps(state.buf_id, state.win_id, state, actions, navigation, opts)
  keymaps.setup_control_keymaps(
    state.buf_id, state.win_id, state, actions, navigation, 
    multi_select, buffer, window_utils, help, config
  )
end

-- Setup keymaps for target selection mode
M.setup_target_selection_keymaps = function()
  if not state.buf_id then return end

  local opts = { noremap = true, silent = true, buffer = state.buf_id }
  keymaps.setup_target_selection_keymaps(state.buf_id, state.win_id, navigation, opts)
end

-- Setup keymaps for multi-select mode
M.setup_multi_select_keymaps = function()
  if not state.buf_id then return end

  local opts = { noremap = true, silent = true, buffer = state.buf_id }
  keymaps.setup_multi_select_keymaps(state.buf_id, state.win_id, navigation, opts)
end

-- Setup keymaps for abandon-specific multi-select mode
M.setup_abandon_select_keymaps = function()
  if not state.buf_id then return end

  local opts = { noremap = true, silent = true, buffer = state.buf_id }
  keymaps.setup_abandon_select_keymaps(state.buf_id, state.win_id, navigation, opts)
end

M.adjust_width = function(delta)
  if not M.is_open() then return end

  local current_width = window_utils.get_width(state.win_id)
  local new_width = math.max(WINDOW_CONSTRAINTS.MIN_WIDTH, math.min(WINDOW_CONSTRAINTS.MAX_WIDTH, current_width + delta))

  -- Update the window width (for split windows, this is straightforward)
  vim.api.nvim_win_set_width(state.win_id, new_width)

  -- Save the new width persistently
  config.persist_window_width(new_width)

  -- Refresh with latest data to apply new wrapping
  require('jj-nvim').refresh()
end

-- Helper function to get current view type
local function get_current_view()
  return state.current_view
end

-- Function to highlight the current content item (commit or bookmark)
M.highlight_current_commit = function()
  if not state.buf_id or not state.win_id or not vim.api.nvim_win_is_valid(state.win_id) then return end

  local ns_id = vim.api.nvim_create_namespace('jj_commit_highlight')

  -- Clear both highlighting namespaces to prevent conflicts
  vim.api.nvim_buf_clear_namespace(state.buf_id, ns_id, 0, -1)

  -- Always clear multi-select namespace - either to reapply with current selections or to clear all
  local multi_select_ns = vim.api.nvim_create_namespace('jj_multi_select')
  vim.api.nvim_buf_clear_namespace(state.buf_id, multi_select_ns, 0, -1)

  -- Get current cursor position
  local cursor = vim.api.nvim_win_get_cursor(state.win_id)
  local display_line_number = cursor[1]

  -- Get the content item at this line (commit or bookmark)
  local content_item = navigation.get_current_commit(state.win_id)
  local cursor_item_id = nil
  if content_item then
    -- Get ID based on content type
    if content_item.content_type == "bookmark" then
      cursor_item_id = content_item.commit_id or content_item.change_id
    else
      cursor_item_id = content_item.change_id or content_item.short_change_id
    end
  end

  -- Apply multi-select highlighting first for all selected items EXCEPT the one under cursor
  if #state.selected_commits > 0 then
    local current_view = get_current_view()
    local content_items = nil
    
    if current_view == "bookmark" then
      content_items = state.bookmark_data
    else
      content_items = buffer.get_commits(state.buf_id)
    end
    
    if content_items then
      local window_width = window_utils.get_width(state.win_id)
      -- Filter out the item under cursor to avoid duplicate highlighting
      local filtered_selected = {}
      for _, selected_id in ipairs(state.selected_commits) do
        if selected_id ~= cursor_item_id then
          table.insert(filtered_selected, selected_id)
        end
      end
      multi_select.highlight_selected_commits(state.buf_id, content_items, filtered_selected, window_width)
    end
  end

  -- Apply cursor highlighting only to the content item under cursor
  if not content_item then return end

  if content_item.line_start and content_item.line_end then
    local window_width = window_utils.get_width(state.win_id)

    -- Check if this item is selected
    local is_selected_item = false
    if state.selected_commits then
      for _, selected_id in ipairs(state.selected_commits) do
        if selected_id == cursor_item_id then
          is_selected_item = true
          break
        end
      end
    end

    -- Choose highlight group based on current mode and selection status
    local highlight_group
    if M.is_mode(MODES.TARGET_SELECT) then
      highlight_group = 'JJTargetSelection'
    elseif is_selected_item then
      highlight_group = 'JJSelectedCommitCursor' -- Special highlight for selected item under cursor
    else
      highlight_group = 'JJCommitSelected'
    end

    -- For bookmarks, line positions are already display-relative
    -- For commits, convert log line numbers to display line numbers
    local display_start, display_end
    if content_item.content_type == "bookmark" then
      display_start = content_item.line_start
      display_end = content_item.line_end
    else
      display_start = buffer.get_display_line_number(content_item.line_start, window_width)
      display_end = buffer.get_display_line_number(content_item.line_end, window_width)
    end

    for line_idx = display_start, display_end do
      -- Get the actual line content to see its length
      local line_content = vim.api.nvim_buf_get_lines(state.buf_id, line_idx - 1, line_idx, false)[1] or ""
      local content_length = vim.fn.strdisplaywidth(line_content)

      -- Highlight the actual content
      vim.api.nvim_buf_add_highlight(state.buf_id, ns_id, highlight_group, line_idx - 1, 0, -1)

      -- Extend highlighting to full window width if content is shorter
      if content_length < window_width then
        -- Add virtual text to fill the remaining space
        vim.api.nvim_buf_set_extmark(state.buf_id, ns_id, line_idx - 1, #line_content, {
          virt_text = { { string.rep(" ", window_width - content_length), highlight_group } },
          virt_text_pos = 'inline'
        })
      end
    end
  end
end

-- Set up commit highlighting system
M.setup_commit_highlighting = function()
  if not state.buf_id or not state.win_id then return end

  -- Define subtle highlight groups for cursor highlighting
  -- Just a subtle light gray background, no foreground color changes
  vim.api.nvim_set_hl(0, 'JJCommitSelected', { bg = '#404040' })              -- Subtle light gray for normal cursor
  vim.api.nvim_set_hl(0, 'JJTargetSelection', { bg = '#505050' })             -- Slightly lighter gray for target selection
  vim.api.nvim_set_hl(0, 'JJSelectedCommitCursor', { bg = '#484848' })        -- Medium gray for selected item under cursor

  -- Set up autocmd to highlight on cursor movement
  vim.api.nvim_create_autocmd({ 'CursorMoved', 'CursorMovedI' }, {
    buffer = state.buf_id,
    callback = M.highlight_current_commit,
    group = vim.api.nvim_create_augroup('JJCommitHighlight_' .. state.buf_id, { clear = true })
  })

  -- Set up autocmd to persist window width changes
  vim.api.nvim_create_autocmd('WinResized', {
    callback = function()
      -- Only handle resize for our window
      if state.win_id and vim.api.nvim_win_is_valid(state.win_id) then
        local current_width = vim.api.nvim_win_get_width(state.win_id)
        local persisted_width = config.get_window_width()
        
        -- Only persist if width actually changed
        if current_width ~= persisted_width then
          config.persist_window_width(current_width)
        end
      end
    end,
    group = vim.api.nvim_create_augroup('JJWindowResize_' .. state.buf_id, { clear = true })
  })

  -- Set up autocmd to restore window size when vim is resized
  vim.api.nvim_create_autocmd('VimResized', {
    callback = function()
      -- Only restore size for our window
      if state.win_id and vim.api.nvim_win_is_valid(state.win_id) then
        local configured_width = config.get_window_width()
        local current_width = vim.api.nvim_win_get_width(state.win_id)
        
        -- Restore the configured width if it changed
        if current_width ~= configured_width then
          vim.api.nvim_win_set_width(state.win_id, configured_width)
        end
      end
    end,
    group = vim.api.nvim_create_augroup('JJVimResize_' .. state.buf_id, { clear = true })
  })

  -- Initial highlighting
  M.highlight_current_commit()
end

M.get_current_line = function()
  if not M.is_open() then return nil end
  local line_nr = vim.api.nvim_win_get_cursor(state.win_id)[1]
  return vim.api.nvim_buf_get_lines(state.buf_id, line_nr - 1, line_nr, false)[1]
end

-- Mode management functions
M.set_mode = function(mode, data)
  state.mode = mode
  state.mode_data = data or {}

  -- Update status display to reflect mode change
  if state.win_id and vim.api.nvim_win_is_valid(state.win_id) then
    local window_width = window_utils.get_width(state.win_id)
    buffer.update_status(state.buf_id, {
      current_mode = mode
    }, window_width)
  end
end

M.get_mode = function()
  return state.mode, state.mode_data
end

M.is_mode = function(mode)
  return state.mode == mode
end

-- View management functions
M.enable_view_toggle = function()
  state.view_toggle_enabled = true
end

M.disable_view_toggle = function()
  state.view_toggle_enabled = false
  -- Always reset to log view when disabling
  state.current_view = VIEW_TYPES.LOG
end

M.get_view = function()
  return state.current_view
end

M.is_view = function(view_type)
  return state.current_view == view_type
end

M.set_view = function(view_type)
  if view_type == VIEW_TYPES.LOG or view_type == VIEW_TYPES.BOOKMARK then
    state.current_view = view_type
    return true
  end
  return false
end

M.toggle_view = function()
  if not state.view_toggle_enabled then
    return false
  end
  
  local new_view = state.current_view == VIEW_TYPES.LOG and VIEW_TYPES.BOOKMARK or VIEW_TYPES.LOG
  M.set_view(new_view)
  
  -- Re-render the buffer with the new view using unified render system
  M.refresh_current_view()
  
  return true
end

M.refresh_current_view = function()
  if not state.win_id or not vim.api.nvim_win_is_valid(state.win_id) then
    return
  end
  
  if state.current_view == VIEW_TYPES.LOG then
    -- Update status to reflect log view
    local status = require('jj-nvim.ui.status')
    status.update_status({
      current_view = "log",
      bookmark_count = 0,
      selected_count = #state.selected_commits
    })
    -- Refresh with normal commit log
    require('jj-nvim').refresh()
  else
    -- Render bookmark view using unified system
    M.render_unified_bookmark_view()
  end
end

M.reset_mode = function()
  -- Clear any target selection UI feedback
  if state.win_id and vim.api.nvim_win_is_valid(state.win_id) then
    -- Reset state first
    local old_mode = state.mode
    state.mode = MODES.NORMAL
    state.mode_data = {}
    state.selected_commits = {} -- Clear multi-select state

    -- If we were in multi-select mode, clear multi-select highlighting
    if old_mode == MODES.MULTI_SELECT then
      -- Clear multi-select highlighting namespace
      local multi_select_ns = vim.api.nvim_create_namespace('jj_multi_select')
      vim.api.nvim_buf_clear_namespace(state.buf_id, multi_select_ns, 0, -1)
    end

    -- Update status display to reflect cleared selections
    local window_width = window_utils.get_width(state.win_id)
    buffer.update_status(state.buf_id, {
      selected_count = #state.selected_commits,
      current_mode = "NORMAL"
    }, window_width)

    M.setup_commit_highlighting() -- Reset to normal highlighting
  else
    -- Just reset state if window is not valid
    state.mode = MODES.NORMAL
    state.mode_data = {}
    state.selected_commits = {}
  end
end

-- Enter target selection mode
M.enter_target_selection_mode = function(action_type, source_commit)
  if not M.is_open() then
    vim.notify("JJ window is not open", vim.log.levels.WARN)
    return
  end

  -- Store current cursor position to return to if cancelled
  local current_line = vim.api.nvim_win_get_cursor(state.win_id)[1]

  local mode_data = {
    action = action_type, -- "after", "before", or "squash"
    original_line = current_line
  }

  -- Store source commit for squash operations
  if action_type == "squash" and source_commit then
    mode_data.source_commit = source_commit
  end

  M.set_mode(MODES.TARGET_SELECT, mode_data)

  -- Enable view toggling for target selection mode
  M.enable_view_toggle()

  -- Update keymaps for target selection
  M.setup_target_selection_keymaps()

  -- Show status message
  local action_desc
  if action_type == "after" then
    action_desc = "after"
    vim.notify(string.format("Select commit to insert %s (Enter to confirm, Esc to cancel)", action_desc),
      vim.log.levels.INFO)
  elseif action_type == "before" then
    action_desc = "before"
    vim.notify(string.format("Select commit to insert %s (Enter to confirm, Esc to cancel)", action_desc),
      vim.log.levels.INFO)
  elseif action_type == "squash" then
    vim.notify("Select target to squash into (Enter to confirm, b for bookmark, Esc to cancel)",
      vim.log.levels.INFO)
  end
end

-- Generic target selection with callbacks (proper architecture)
M.enter_generic_target_selection = function(options)
  if not M.is_open() then
    vim.notify("JJ window is not open", vim.log.levels.WARN)
    return
  end
  
  options = options or {}
  
  -- Store current cursor position to return to if cancelled
  local current_line = vim.api.nvim_win_get_cursor(state.win_id)[1]
  local mode_data = {
    action = "generic",
    original_line = current_line,
    callbacks = {
      on_confirm = options.on_confirm,
      on_cancel = options.on_cancel
    }
  }
  
  M.set_mode(MODES.TARGET_SELECT, mode_data)
  -- Enable view toggling for target selection mode
  M.enable_view_toggle()
  -- Update keymaps for target selection
  M.setup_target_selection_keymaps()
  -- Show status message
  local title = options.title or "Select target"
  vim.notify(title .. " (Enter to confirm, b for bookmark, Esc to cancel)", vim.log.levels.INFO)
end

-- Enter rebase multi-select mode for revisions
M.enter_rebase_multi_select_mode = function(initial_commit)
  if not M.is_open() then
    vim.notify("JJ window is not open", vim.log.levels.WARN)
    return
  end

  -- Initialize selection with the initial commit if provided
  state.selected_commits = {}
  if initial_commit then
    local commit_utils = require('jj-nvim.core.commit')
    local change_id = commit_utils.get_id(initial_commit)
    if change_id then
      table.insert(state.selected_commits, change_id)
    end
  end

  -- Enter multi-select mode
  M.set_mode(MODES.MULTI_SELECT, {
    action = "rebase_revisions_select",
    original_selection = vim.deepcopy(state.selected_commits)
  })

  -- Enable view toggling for multi-select mode
  M.enable_view_toggle()

  -- Setup multi-select keymaps
  M.setup_rebase_multi_select_keymaps()

  -- Update highlighting and status
  M.highlight_current_commit()
  local window_width = window_utils.get_width(state.win_id)
  buffer.update_status(state.buf_id, {
    selected_count = #state.selected_commits,
    current_mode = "REBASE_SELECT"
  }, window_width)
end

-- Setup keymaps for rebase multi-select mode
M.setup_rebase_multi_select_keymaps = function()
  if not state.buf_id then return end

  local opts = { noremap = true, silent = true, buffer = state.buf_id }

  -- Clear conflicting keymaps
  keymaps.clear_conflicting_keymaps(state.buf_id)

  -- Setup navigation with selection update callback
  keymaps.setup_common_navigation(state.buf_id, state.win_id, navigation, opts, function()
    M.highlight_current_commit()
  end)

  -- Toggle commit selection using configured key
  local config = require('jj-nvim.config')
  local toggle_selection_key = config.get_first_keybind('keybinds.log_window.special_modes.multi_select.toggle_selection') or '<Space>'
  vim.keymap.set('n', toggle_selection_key, function()
    local commit = navigation.get_current_commit(state.win_id)
    if commit then
      state.selected_commits = multi_select.toggle_commit_selection(commit, state.selected_commits)
      M.highlight_current_commit()
      
      -- Update status display
      local window_width = window_utils.get_width(state.win_id)
      buffer.update_status(state.buf_id, {
        selected_count = #state.selected_commits,
        current_mode = "REBASE_SELECT"
      }, window_width)
    end
  end, opts)

  -- Confirm selection and proceed to target selection using configured key
  local confirm_key = config.get_first_keybind('keybinds.log_window.special_modes.multi_select.confirm') or '<CR>'
  vim.keymap.set('n', confirm_key, function()
    M.confirm_rebase_multi_selection()
  end, opts)

  -- Cancel multi-select mode using configured key
  local cancel_key = config.get_first_keybind('keybinds.log_window.special_modes.multi_select.cancel') or '<Esc>'
  vim.keymap.set('n', cancel_key, function()
    M.cancel_rebase_multi_selection()
  end, opts)

  -- Disable other actions during multi-select
  keymaps.setup_disabled_actions(state.buf_id, "Multi-select mode active. Use Space to select, Enter to continue, Esc to cancel.", opts)
end

-- Confirm rebase multi-selection and proceed to target selection
M.confirm_rebase_multi_selection = function()
  if not M.is_mode(MODES.MULTI_SELECT) then
    return
  end

  if #state.selected_commits == 0 then
    vim.notify("No commits selected for rebase", vim.log.levels.WARN)
    return
  end

  -- Store selected commits for rebase
  local selected_commits = vim.deepcopy(state.selected_commits)
  
  -- Clear multi-select mode
  state.selected_commits = {}
  M.reset_mode()

  -- Show destination selection menu
  vim.notify(string.format("Selected %d commit%s. Choose destination type:", 
    #selected_commits, #selected_commits > 1 and "s" or ""), vim.log.levels.INFO)
  
  M.show_rebase_destination_menu(selected_commits)
end

-- Cancel rebase multi-selection
M.cancel_rebase_multi_selection = function()
  if not M.is_mode(MODES.MULTI_SELECT) then
    return
  end

  -- Clear selections and return to normal mode
  state.selected_commits = {}
  M.reset_mode()
  M.setup_keymaps()

  -- Update status and highlighting
  M.highlight_current_commit()
  local window_width = window_utils.get_width(state.win_id)
  buffer.update_status(state.buf_id, {
    selected_count = 0,
    current_mode = "NORMAL"
  }, window_width)

  vim.notify("Rebase multi-selection cancelled", vim.log.levels.INFO)
end

-- Show rebase destination selection menu
M.show_rebase_destination_menu = function(selected_commits)
  local inline_menu = require('jj-nvim.ui.inline_menu')
  
  local menu_config = {
    title = string.format("Rebase %d commit%s to:", #selected_commits, #selected_commits > 1 and "s" or ""),
    items = {
      {
        key = "d",
        description = "Select destination (-d)",
        action = "select_destination",
      },
      {
        key = "a",
        description = "Select insert-after (-A)",
        action = "select_insert_after",
      },
      {
        key = "b",
        description = "Select insert-before (-B)",
        action = "select_insert_before",
      },
    }
  }

  inline_menu.show(state.win_id, menu_config, {
    on_select = function(selected_item)
      local action = selected_item.action
      local target_type = action:gsub("select_", "")
      if target_type == "destination" then
        target_type = "destination"
      elseif target_type == "insert_after" then
        target_type = "insert_after"
      elseif target_type == "insert_before" then
        target_type = "insert_before"
      end
      
      M.enter_rebase_multi_target_selection_mode(target_type, selected_commits)
    end,
    on_cancel = function()
      vim.notify("Rebase cancelled", vim.log.levels.INFO)
    end
  })
end

-- Enter target selection mode for multi-commit rebase
M.enter_rebase_multi_target_selection_mode = function(target_type, selected_commits)
  if not M.is_open() then
    vim.notify("JJ window is not open", vim.log.levels.WARN)
    return
  end

  local current_line = vim.api.nvim_win_get_cursor(state.win_id)[1]

  local mode_data = {
    action = "rebase_multi_" .. target_type,
    target_type = target_type,
    selected_commits = selected_commits,
    original_line = current_line
  }

  M.set_mode(MODES.TARGET_SELECT, mode_data)
  M.setup_target_selection_keymaps()

  local action_desc
  if target_type == "destination" then
    action_desc = "select destination to rebase onto"
  elseif target_type == "insert_after" then
    action_desc = "select target to insert after"
  elseif target_type == "insert_before" then
    action_desc = "select target to insert before"
  end

  vim.notify(string.format("Multi-commit rebase: %s (Enter to confirm, Esc to cancel)", action_desc), vim.log.levels.INFO)
end

-- Enter rebase target selection mode
M.enter_rebase_target_selection_mode = function(rebase_target_type, source_commit, rebase_mode)
  if not M.is_open() then
    vim.notify("JJ window is not open", vim.log.levels.WARN)
    return
  end

  -- Store current cursor position to return to if cancelled
  local current_line = vim.api.nvim_win_get_cursor(state.win_id)[1]

  local mode_data = {
    action = "rebase_" .. rebase_target_type, -- "rebase_destination", "rebase_insert_after", "rebase_insert_before"
    rebase_target_type = rebase_target_type, -- "destination", "insert_after", "insert_before"
    rebase_mode = rebase_mode or "branch", -- "branch", "source", "revisions"
    source_commit = source_commit,
    original_line = current_line
  }

  M.set_mode(MODES.TARGET_SELECT, mode_data)

  -- Update keymaps for target selection
  M.setup_target_selection_keymaps()

  -- Show appropriate status message
  local action_desc
  if rebase_target_type == "destination" then
    action_desc = "select destination to rebase onto"
  elseif rebase_target_type == "insert_after" then
    action_desc = "select target to insert after"
  elseif rebase_target_type == "insert_before" then
    action_desc = "select target to insert before"
  end

  local mode_desc = ""
  if rebase_mode == "branch" then
    mode_desc = " (branch mode)"
  elseif rebase_mode == "source" then
    mode_desc = " (source mode)"
  elseif rebase_mode == "revisions" then
    mode_desc = " (revisions mode)"
  end

  vim.notify(string.format("Rebase mode: %s%s (Enter to confirm, Esc to cancel)", action_desc, mode_desc), vim.log.levels.INFO)
end

-- Enter split target selection mode
M.enter_split_target_selection_mode = function(split_action, source_commit)
  if not M.is_open() then
    vim.notify("JJ window is not open", vim.log.levels.WARN)
    return
  end

  -- Store current cursor position to return to if cancelled
  local current_line = vim.api.nvim_win_get_cursor(state.win_id)[1]

  local mode_data = {
    action = "split_" .. split_action, -- "split_insert_after", "split_insert_before", "split_destination"
    split_action = split_action, -- "insert_after", "insert_before", "destination"
    source_commit = source_commit,
    original_line = current_line
  }

  M.set_mode(MODES.TARGET_SELECT, mode_data)

  -- Update keymaps for target selection
  M.setup_target_selection_keymaps()

  -- Show appropriate status message
  local action_desc
  if split_action == "insert_after" then
    action_desc = "select target to insert split result after"
  elseif split_action == "insert_before" then
    action_desc = "select target to insert split result before"
  elseif split_action == "destination" then
    action_desc = "select destination to rebase split result onto"
  end

  vim.notify(string.format("Split mode: %s (Enter to confirm, Esc to cancel)", action_desc), vim.log.levels.INFO)
end

-- Confirm target selection and execute action
M.confirm_target_selection = function()
  if not M.is_mode(MODES.TARGET_SELECT) then
    return
  end

  local mode_data = select(2, M.get_mode())
  local target_commit = navigation.get_current_commit(state.win_id)

  if not target_commit then
    vim.notify("No valid commit selected", vim.log.levels.WARN)
    return
  end

  local action_type = mode_data.action
  local success = false

  if action_type == "after" then
    success = actions.new_after(target_commit)
    if success then
      require('jj-nvim').refresh()
    end
    -- Return to normal mode
    M.reset_mode()
    M.disable_view_toggle() -- Disable view toggling
    M.setup_keymaps() -- Restore normal keymaps
  elseif action_type == "before" then
    success = actions.new_before(target_commit)
    if success then
      require('jj-nvim').refresh()
    end
    -- Return to normal mode
    M.reset_mode()
    M.disable_view_toggle() -- Disable view toggling
    M.setup_keymaps() -- Restore normal keymaps
  elseif action_type == "squash" then
    -- For squash, don't execute immediately - show options menu first
    local source_commit = mode_data.source_commit
    M.reset_mode()
    M.disable_view_toggle() -- Disable view toggling
    M.setup_keymaps() -- Restore normal keymaps

    -- Show squash options menu with source commit information
    actions.show_squash_options_menu(target_commit, "commit", state.win_id, source_commit)
  elseif action_type == "generic" then
    -- Generic target selection with custom callbacks
    local callbacks = mode_data.callbacks
    M.reset_mode()
    M.disable_view_toggle() -- Disable view toggling
    M.setup_keymaps() -- Restore normal keymaps
    
    if callbacks and callbacks.on_confirm then
      -- Determine target type
      local target_type = "commit"
      if target_commit.content_type == "bookmark" then
        target_type = "bookmark"
      end
      
      callbacks.on_confirm(target_commit, target_type)
    end
  elseif action_type == "split_insert_after" then
    -- Execute split with insert-after
    local source_commit = mode_data.source_commit
    local target_change_id = commit_utils.get_id(target_commit)
    if not target_change_id or target_change_id == "" then
      vim.notify("Failed to get target commit ID", vim.log.levels.ERROR)
      return
    end

    local options = {
      insert_after = { target_change_id },
      interactive = true
    }
    
    success = actions.split_commit(source_commit, options)
    if success then
      require('jj-nvim').refresh()
    end
    
    -- Return to normal mode
    M.reset_mode()
    M.setup_keymaps()
  elseif action_type == "split_insert_before" then
    -- Execute split with insert-before
    local source_commit = mode_data.source_commit
    local target_change_id = commit_utils.get_id(target_commit)
    if not target_change_id or target_change_id == "" then
      vim.notify("Failed to get target commit ID", vim.log.levels.ERROR)
      return
    end

    local options = {
      insert_before = { target_change_id },
      interactive = true
    }
    
    success = actions.split_commit(source_commit, options)
    if success then
      require('jj-nvim').refresh()
    end
    
    -- Return to normal mode
    M.reset_mode()
    M.setup_keymaps()
  elseif action_type == "split_destination" then
    -- Execute split with destination
    local source_commit = mode_data.source_commit
    local target_change_id = commit_utils.get_id(target_commit)
    if not target_change_id or target_change_id == "" then
      vim.notify("Failed to get target commit ID", vim.log.levels.ERROR)
      return
    end

    local options = {
      destination = { target_change_id },
      interactive = true
    }
    
    success = actions.split_commit(source_commit, options)
    if success then
      require('jj-nvim').refresh()
    end
    
    -- Return to normal mode
    M.reset_mode()
    M.setup_keymaps()
  elseif action_type == "rebase_destination" then
    -- Execute rebase to destination
    local source_commit = mode_data.source_commit
    local target_change_id = commit_utils.get_id(target_commit)
    if not target_change_id or target_change_id == "" then
      vim.notify("Failed to get target commit ID", vim.log.levels.ERROR)
      return
    end

    local options = {
      mode = mode_data.rebase_mode,
      destination = target_change_id
    }
    
    success = actions.rebase_commit(source_commit, options)
    if success then
      require('jj-nvim').refresh()
    end
    
    -- Return to normal mode
    M.reset_mode()
    M.setup_keymaps()
  elseif action_type == "rebase_insert_after" then
    -- Execute rebase with insert-after
    local source_commit = mode_data.source_commit
    local target_change_id = commit_utils.get_id(target_commit)
    if not target_change_id or target_change_id == "" then
      vim.notify("Failed to get target commit ID", vim.log.levels.ERROR)
      return
    end

    local options = {
      mode = mode_data.rebase_mode,
      insert_after = target_change_id
    }
    
    success = actions.rebase_commit(source_commit, options)
    if success then
      require('jj-nvim').refresh()
    end
    
    -- Return to normal mode
    M.reset_mode()
    M.setup_keymaps()
  elseif action_type == "rebase_insert_before" then
    -- Execute rebase with insert-before
    local source_commit = mode_data.source_commit
    local target_change_id = commit_utils.get_id(target_commit)
    if not target_change_id or target_change_id == "" then
      vim.notify("Failed to get target commit ID", vim.log.levels.ERROR)
      return
    end

    local options = {
      mode = mode_data.rebase_mode,
      insert_before = target_change_id
    }
    
    success = actions.rebase_commit(source_commit, options)
    if success then
      require('jj-nvim').refresh()
    end
    
    -- Return to normal mode
    M.reset_mode()
    M.setup_keymaps()
  elseif action_type == "rebase_multi_destination" then
    -- Execute multi-commit rebase to destination
    local selected_commits = mode_data.selected_commits
    local target_change_id = commit_utils.get_id(target_commit)
    if not target_change_id or target_change_id == "" then
      vim.notify("Failed to get target commit ID", vim.log.levels.ERROR)
      return
    end

    local options = {
      destination = target_change_id
    }
    
    success = actions.rebase_multiple_commits(selected_commits, options)
    if success then
      require('jj-nvim').refresh()
    end
    
    -- Return to normal mode
    M.reset_mode()
    M.setup_keymaps()
  elseif action_type == "rebase_multi_insert_after" then
    -- Execute multi-commit rebase with insert-after
    local selected_commits = mode_data.selected_commits
    local target_change_id = commit_utils.get_id(target_commit)
    if not target_change_id or target_change_id == "" then
      vim.notify("Failed to get target commit ID", vim.log.levels.ERROR)
      return
    end

    local options = {
      insert_after = target_change_id
    }
    
    success = actions.rebase_multiple_commits(selected_commits, options)
    if success then
      require('jj-nvim').refresh()
    end
    
    -- Return to normal mode
    M.reset_mode()
    M.setup_keymaps()
  elseif action_type == "rebase_multi_insert_before" then
    -- Execute multi-commit rebase with insert-before
    local selected_commits = mode_data.selected_commits
    local target_change_id = commit_utils.get_id(target_commit)
    if not target_change_id or target_change_id == "" then
      vim.notify("Failed to get target commit ID", vim.log.levels.ERROR)
      return
    end

    local options = {
      insert_before = target_change_id
    }
    
    success = actions.rebase_multiple_commits(selected_commits, options)
    if success then
      require('jj-nvim').refresh()
    end
    
    -- Return to normal mode
    M.reset_mode()
    M.setup_keymaps()
  end
end

-- Cancel target selection and return to normal mode
M.cancel_target_selection = function()
  if not M.is_mode(MODES.TARGET_SELECT) then
    return
  end

  local mode_data = select(2, M.get_mode())

  -- Return cursor to original position
  if mode_data.original_line and state.win_id and vim.api.nvim_win_is_valid(state.win_id) then
    vim.api.nvim_win_set_cursor(state.win_id, { mode_data.original_line, 0 })
  end

  -- Call cancel callback for generic target selection
  if mode_data.action == "generic" and mode_data.callbacks and mode_data.callbacks.on_cancel then
    mode_data.callbacks.on_cancel()
  end

  -- Return to normal mode
  M.reset_mode()
  M.disable_view_toggle() -- Disable view toggling
  M.setup_keymaps() -- Restore normal keymaps

  if mode_data.action ~= "generic" then
    vim.notify("Target selection cancelled", vim.log.levels.INFO)
  end
end

-- Show new change creation menu
M.show_new_change_menu = function()
  if not M.is_open() then
    vim.notify("JJ window is not open", vim.log.levels.WARN)
    return
  end

  -- Check if menu is already active
  if inline_menu.is_active() then
    vim.notify("Menu is already active", vim.log.levels.INFO)
    return
  end

  -- Get current commit for context
  local current_commit = navigation.get_current_commit(state.win_id)
  if not current_commit then
    vim.notify("No commit found at cursor position", vim.log.levels.WARN)
    return
  end

  -- Define menu configuration
  local menu_config = {
    id = "new_change",
    title = "Create New Change",
    items = {
      {
        key = "a",
        description = "Create new change after (select target)",
        action = "new_after",
        data = {}
      },
      {
        key = "b",
        description = "Create new change before (select target)",
        action = "new_before",
        data = {}
      },
      {
        key = "m",
        description = "Create merge commit (select multiple parents)",
        action = "multi_select",
        data = {}
      }
    }
  }

  -- Show the menu
  local success = inline_menu.show(state.win_id, menu_config, {
    on_select = function(selected_item)
      M.handle_new_change_selection(selected_item)
    end,
    on_cancel = function()
      M.reset_mode()
    end
  })

  if success then
    M.set_mode(MODES.NEW_MENU, { menu_config = menu_config })
  else
    vim.notify("Failed to show menu", vim.log.levels.ERROR)
  end
end

-- Handle new change menu selection
M.handle_new_change_selection = function(selected_item)
  M.reset_mode()

  if selected_item.action == "new_child_with_description" then
    -- New child creation with custom message
    vim.ui.input({ prompt = "Commit description: " }, function(message)
      if message and message ~= "" then
        if actions.new_child(selected_item.data.parent, { message = message }) then
          require('jj-nvim').refresh()
        end
      else
        vim.notify("New change cancelled", vim.log.levels.INFO)
      end
    end)
  elseif selected_item.action == "new_after" then
    -- Enter target selection mode for after
    M.enter_target_selection_mode("after")
  elseif selected_item.action == "new_before" then
    -- Enter target selection mode for before
    M.enter_target_selection_mode("before")
  elseif selected_item.action == "multi_select" then
    -- Enter multi-select mode for merge commit
    M.enter_multi_select_mode()
  else
    -- Fallback for unknown actions
    vim.notify("Feature not yet implemented: " .. selected_item.description, vim.log.levels.INFO)
  end
end

-- Enter multi-select mode for creating merge commits
M.enter_multi_select_mode = function()
  if not M.is_open() then
    vim.notify("JJ window is not open", vim.log.levels.WARN)
    return
  end

  -- Store current cursor position
  local current_line = vim.api.nvim_win_get_cursor(state.win_id)[1]

  M.set_mode(MODES.MULTI_SELECT, {
    original_line = current_line
  })

  -- Initialize selection state
  state.selected_commits = {}

  -- Update keymaps for multi-select
  M.setup_multi_select_keymaps()

  -- Refresh buffer to show selection highlighting
  M.refresh_buffer()

  -- Show status message
  vim.notify("Multi-select mode: Use Space to toggle selection, Enter to confirm, Esc to cancel", vim.log.levels.INFO)
end

-- Enter multi-select mode specifically for abandon workflow
M.enter_abandon_select_mode = function()
  if not M.is_open() then
    vim.notify("JJ window is not open", vim.log.levels.WARN)
    return
  end

  -- Store current cursor position
  local current_line = vim.api.nvim_win_get_cursor(state.win_id)[1]

  M.set_mode(MODES.MULTI_SELECT, {
    original_line = current_line,
    workflow = 'abandon'  -- Mark this as abandon workflow
  })

  -- Initialize selection state
  state.selected_commits = {}

  -- Update keymaps for multi-select with abandon-specific confirmation
  M.setup_abandon_select_keymaps()

  -- Refresh buffer to show selection highlighting
  M.refresh_buffer()

  -- Show status message
  vim.notify("Abandon mode: Use Space to select commits, Enter to abandon selected, Esc to cancel", vim.log.levels.INFO)
end

-- Toggle commit selection in multi-select mode
M.toggle_commit_selection = function()
  if not M.is_mode(MODES.MULTI_SELECT) then
    return
  end

  local current_commit = navigation.get_current_commit(state.win_id)
  if not current_commit then
    vim.notify("No commit at cursor position", vim.log.levels.WARN)
    return
  end

  -- Toggle selection
  state.selected_commits = multi_select.toggle_commit_selection(current_commit, state.selected_commits)

  -- Update display
  M.update_multi_select_display()
end

-- Update multi-select display (highlighting and column)
M.update_multi_select_display = function()
  if not M.is_mode(MODES.MULTI_SELECT) or not state.buf_id then
    return
  end

  -- Use the same highlighting logic that prevents duplicate extmarks
  M.highlight_current_commit()
end

-- Confirm multi-selection and create merge commit
M.confirm_multi_selection = function()
  if not M.is_mode(MODES.MULTI_SELECT) then
    return
  end

  local mixed_entries = buffer.get_commits(state.buf_id)
  if not mixed_entries then
    vim.notify("No commits available", vim.log.levels.WARN)
    return
  end

  -- Simple validation: just check we have at least 2 commits selected
  if not state.selected_commits or #state.selected_commits < 2 then
    vim.notify("At least 2 commits must be selected for a multi-parent change", vim.log.levels.WARN)
    return
  end

  -- Show selection summary and confirm (show short version of IDs for readability)
  local short_ids = {}
  for _, change_id in ipairs(state.selected_commits) do
    table.insert(short_ids, change_id:sub(1, 8))
  end
  local commit_summary = table.concat(short_ids, ", ")
  local confirm_msg = string.format("Create merge commit with %d parents: %s?", #state.selected_commits, commit_summary)

  -- Use vim.ui.select for better confirmation
  vim.ui.select({ 'Yes', 'No' }, {
    prompt = confirm_msg,
  }, function(choice)
    if choice == 'Yes' then
      -- Create the merge commit directly using the selected change IDs
      local success = actions.new_with_change_ids(state.selected_commits)

      if success then
        require('jj-nvim').refresh()
      end

      -- Return to normal mode
      M.reset_mode()
      M.disable_view_toggle() -- Disable view toggling
      M.setup_keymaps() -- Restore normal keymaps
    else
      vim.notify("Merge commit creation cancelled", vim.log.levels.INFO)
    end
  end)
end

-- Confirm abandon selection and show abandon options
M.confirm_abandon_selection = function()
  if not M.is_mode(MODES.MULTI_SELECT) then
    return
  end

  local mixed_entries = buffer.get_commits(state.buf_id)
  if not mixed_entries then
    vim.notify("No commits available", vim.log.levels.WARN)
    return
  end

  -- Check if we have at least 1 commit selected
  if not state.selected_commits or #state.selected_commits < 1 then
    vim.notify("At least 1 commit must be selected for abandon", vim.log.levels.WARN)
    return
  end

  -- Execute abandon operation directly with single confirmation
  local actions = require('jj-nvim.jj.actions')
  actions.abandon_multiple_commits_async(state.selected_commits, function()
    require('jj-nvim').refresh()
  end)

  -- Return to normal mode
  M.reset_mode()
  M.disable_view_toggle() -- Disable view toggling
  M.setup_keymaps() -- Restore normal keymaps
end

-- Cancel multi-selection and return to normal mode
M.cancel_multi_selection = function()
  if not M.is_mode(MODES.MULTI_SELECT) then
    return
  end

  local mode_data = select(2, M.get_mode())

  -- Return cursor to original position
  if mode_data.original_line and state.win_id and vim.api.nvim_win_is_valid(state.win_id) then
    vim.api.nvim_win_set_cursor(state.win_id, { mode_data.original_line, 0 })
  end

  -- Return to normal mode
  M.reset_mode()
  M.disable_view_toggle() -- Disable view toggling
  M.setup_keymaps() -- Restore normal keymaps

  vim.notify("Multi-selection cancelled", vim.log.levels.INFO)
end

-- Refresh buffer (with multi-select highlighting if active)
M.refresh_buffer = function()
  if not state.buf_id then
    return false
  end

  -- Parse latest commits
  local parser = require('jj-nvim.core.parser')
  local commits, err = parser.parse_all_commits_with_separate_graph()
  if err then
    vim.notify("Failed to refresh commits: " .. err, vim.log.levels.ERROR)
    return false
  end

  commits = commits or {}

  -- Update buffer content (no more selection column injection)
  local window_width = window_utils.get_width(state.win_id)
  local success = buffer.update_from_commits(state.buf_id, commits, buffer.get_mode(), window_width)

  -- Apply selection highlighting if in multi-select mode
  if M.is_mode(MODES.MULTI_SELECT) then
    -- Schedule highlighting to ensure buffer is fully updated
    vim.schedule(function()
      if state.buf_id and vim.api.nvim_buf_is_valid(state.buf_id) then
        local window_width = state.win_id and vim.api.nvim_win_is_valid(state.win_id) and
            vim.api.nvim_win_get_width(state.win_id) or 80
        multi_select.highlight_selected_commits(state.buf_id, commits, state.selected_commits, window_width)
      end
    end)
  end

  return success
end

-- Toggle description expansion for current commit
M.toggle_description_expansion = function()
  local commit = navigation.get_current_commit(state.win_id)
  if not commit then
    -- Silently do nothing if no commit under cursor - status will show this
    return
  end

  -- Check if this commit has expandable descriptions
  if not commit:has_expandable_description() then
    -- Silently do nothing - visual indicators already show which commits are expandable
    return
  end

  -- First, collapse any other expanded commits
  local all_commits = buffer.get_commits()
  if all_commits then
    for _, c in ipairs(all_commits) do
      if c ~= commit then
        c.expanded = false
      end
    end
  end

  -- Toggle expansion state on the commit object itself
  commit.expanded = not commit.expanded

  -- Re-render buffer with updated expansion state
  local all_commits = buffer.get_commits()
  if all_commits then
    local window_width = window_utils.get_width(state.win_id)
    buffer.update_from_commits(state.buf_id, all_commits, buffer.get_mode(), window_width)
  end
end

-- Show bookmark selection menu
M.show_bookmark_selection_menu = function(options)
  options = options or {}
  local filter_type = options.filter or "local" -- "local", "remote", "all"
  local title = options.title or "Select Bookmark"
  local on_select = options.on_select
  local allow_toggle = options.allow_toggle ~= false -- Default to true

  if not on_select then
    vim.notify("No selection callback provided", vim.log.levels.ERROR)
    return false
  end

  if not M.is_open() then
    vim.notify("JJ window is not open", vim.log.levels.WARN)
    return false
  end

  -- Check if menu is already active
  if inline_menu.is_active() then
    vim.notify("Menu is already active", vim.log.levels.INFO)
    return false
  end

  -- Load bookmarks based on filter

  local bookmark_options = {}
  if filter_type == "all" then
    bookmark_options.all_remotes = true
  elseif filter_type == "remote" then
    bookmark_options.all_remotes = true
  end
  -- For "local", use default options (no flags)

  -- Get bookmarks using new simplified functions
  local filtered_bookmarks = {}
  if filter_type == "local" then
    filtered_bookmarks = bookmark_commands.get_local_bookmarks()
  elseif filter_type == "remote" then
    filtered_bookmarks = bookmark_commands.get_remote_bookmarks()
  elseif filter_type == "all" then
    filtered_bookmarks = bookmark_commands.get_all_present_bookmarks()
  end

  if #filtered_bookmarks == 0 then
    local filter_desc = filter_type == "local" and "local" or (filter_type == "remote" and "remote" or "")
    vim.notify(string.format("No %s bookmarks found", filter_desc), vim.log.levels.INFO)
    return false
  end

  -- Get current commit to prioritize its bookmarks
  local current_commit = navigation.get_current_commit(state.win_id)
  local current_commit_id = nil
  if current_commit then
    current_commit_id = current_commit.change_id or current_commit.short_change_id
  end

  -- Sort bookmarks: current commit bookmarks first (alphabetically), then others (alphabetically)
  table.sort(filtered_bookmarks, function(a, b)
    local a_is_current = false
    local b_is_current = false

    if current_commit_id then
      -- Check if bookmark targets current commit (using prefix matching for short IDs)
      if a.commit_id then
        a_is_current = a.commit_id == current_commit_id or
            a.commit_id:find("^" .. current_commit_id) or
            current_commit_id:find("^" .. a.commit_id)
      end
      if b.commit_id then
        b_is_current = b.commit_id == current_commit_id or
            b.commit_id:find("^" .. current_commit_id) or
            current_commit_id:find("^" .. b.commit_id)
      end
    end

    -- Current commit bookmarks come first
    if a_is_current and not b_is_current then
      return true
    elseif not a_is_current and b_is_current then
      return false
    else
      -- Both are current or both are not current: sort alphabetically
      return a.display_name < b.display_name
    end
  end)

  -- Build menu items
  local menu_items = {}
  for i, bookmark in ipairs(filtered_bookmarks) do
    local description = bookmark.display_name

    -- Add indicator if bookmark is on current commit
    if current_commit_id and bookmark.commit_id then
      local is_current = bookmark.commit_id == current_commit_id or
          bookmark.commit_id:find("^" .. current_commit_id) or
          current_commit_id:find("^" .. bookmark.commit_id)
      if is_current then
        description = "* " .. description
      end
    end

    table.insert(menu_items, {
      key = tostring(i),
      description = description,
      action = "select_bookmark",
      data = { bookmark = bookmark }
    })
  end

  -- Add toggle functionality via special keymap (not as a menu item)
  local toggle_desc = ""
  local filter_display = ""
  if filter_type == "local" then
    toggle_desc = "t - Show remote bookmarks"
    filter_display = "Local"
  elseif filter_type == "remote" then
    toggle_desc = "t - Show all bookmarks"
    filter_display = "Remote"
  else
    toggle_desc = "t - Show local only"
    filter_display = "All"
  end

  local menu_config = {
    id = "bookmark_selection",
    title = title .. " (" .. filter_display .. ") - " .. toggle_desc,
    items = menu_items,
    toggle_desc = toggle_desc,
    toggle_data = { current_filter = filter_type, options = options }
  }

  -- Show the menu
  local callbacks = {
    on_select = function(selected_item)
      if selected_item.action == "select_bookmark" then
        on_select(selected_item.data.bookmark)
      elseif selected_item.action == "toggle_filter" then
        -- Toggle filter and re-show menu
        local current_filter = selected_item.data.current_filter
        local new_filter = "local"
        if current_filter == "local" then
          new_filter = "remote"
        elseif current_filter == "remote" then
          new_filter = "all"
        else
          new_filter = "local"
        end

        -- Close current menu first
        inline_menu = require('jj-nvim.ui.inline_menu')
        inline_menu.close()

        -- Schedule the new menu to open after the current one is fully closed
        vim.schedule(function()
          local new_options = vim.tbl_deep_extend("force", selected_item.data.options, { filter = new_filter })
          -- Preserve navigation callbacks when toggling
          if options.parent_menu_callback then
            new_options.parent_menu_callback = options.parent_menu_callback
          end
          if options.on_cancel then
            new_options.on_cancel = options.on_cancel
          end
          M.show_bookmark_selection_menu(new_options)
        end)
      end
    end,
  }

  -- Pass through navigation callbacks if they exist in options
  if options.parent_menu_callback then
    callbacks.parent_menu_callback = options.parent_menu_callback
  end

  if options.on_cancel then
    callbacks.on_cancel = options.on_cancel
  end

  local success = inline_menu.show(state.win_id, menu_config, callbacks)

  return success
end

-- Show bookmark operations menu
M.show_bookmark_menu = function()
  if not M.is_open() then
    vim.notify("JJ window is not open", vim.log.levels.WARN)
    return
  end

  -- Check if menu is already active
  if inline_menu.is_active() then
    vim.notify("Menu is already active", vim.log.levels.INFO)
    return
  end

  -- Clear menu stack since this is a top-level menu
  clear_menu_stack()

  -- Get current commit for context (used for create/move operations)
  local current_commit = navigation.get_current_commit(state.win_id)

  -- Define menu configuration
  local menu_config = {
    id = "bookmark_operations",
    title = "Bookmark Operations",
    items = {
      {
        key = "c",
        description = "Create bookmark here",
        action = "create_bookmark",
        data = { commit = current_commit }
      },
      {
        key = "d",
        description = "Delete bookmark",
        action = "delete_bookmark",
        data = {}
      },
      {
        key = "m",
        description = "Move bookmark here",
        action = "move_bookmark",
        data = { commit = current_commit }
      },
      {
        key = "r",
        description = "Rename bookmark",
        action = "rename_bookmark",
        data = {}
      },
      {
        key = "l",
        description = "List bookmarks",
        action = "list_bookmarks",
        data = {}
      }
    }
  }

  -- Show the menu
  local success = inline_menu.show(state.win_id, menu_config, {
    on_select = function(selected_item)
      M.handle_bookmark_menu_selection(selected_item)
    end,
    on_cancel = function()
      -- Top-level menu - just clear stack
      clear_menu_stack()
    end
  })

  if not success then
    vim.notify("Failed to show bookmark menu", vim.log.levels.ERROR)
  end
end

-- Handle bookmark menu selection
M.handle_bookmark_menu_selection = function(selected_item)
  if selected_item.action == "create_bookmark" then
    -- Create new bookmark
    vim.ui.input({ prompt = "Enter bookmark name: " }, function(name)
      if name == nil then
        -- User cancelled with Esc
        return
      end

      if name and name ~= "" then
        local commit = selected_item.data.commit
        if not commit then
          vim.notify("No commit under cursor", vim.log.levels.WARN)
          return
        end

        local revision = commit.change_id or commit.short_change_id

        if bookmark_commands.create_bookmark(name, revision) then
          -- Refresh with latest data
          require('jj-nvim').refresh()
        end
      end
    end)
  elseif selected_item.action == "delete_bookmark" then
    -- Show bookmark selection menu for deletion
    vim.schedule(function()
      show_bookmark_selection_with_navigation({
        title = "Select Bookmark to Delete",
        filter = "local",     -- Only local bookmarks can be deleted
        allow_toggle = false, -- No need to toggle for delete
        on_select = function(bookmark)
          -- Confirm deletion
          vim.ui.select({ 'Yes', 'No' }, {
            prompt = string.format("Delete bookmark '%s'?", bookmark.display_name),
          }, function(choice)
            if choice == 'Yes' then
              if bookmark_commands.delete_bookmark(bookmark.name) then
                -- Refresh with latest data
                require('jj-nvim').refresh()
              end
            end
          end)
        end
      }, {
        type = "bookmark_operations",
        title = "Bookmark Operations"
      })
    end)
  elseif selected_item.action == "move_bookmark" then
    -- Show bookmark selection menu for moving
    local target_commit = selected_item.data.commit

    if not target_commit then
      vim.notify("No commit under cursor", vim.log.levels.WARN)
      return
    end

    vim.schedule(function()
      show_bookmark_selection_with_navigation({
        title = "Select Bookmark to Move Here",
        filter = "local", -- Only local bookmarks can be moved
        allow_toggle = false,
        on_select = function(bookmark)
          local target_revision = target_commit.change_id or target_commit.short_change_id

          -- Create options with success callback
          local move_options = {
            on_success = function()
              -- Refresh with latest data
              require('jj-nvim').refresh()
            end
          }

          bookmark_commands.move_bookmark(bookmark.name, target_revision, move_options)
        end
      }, {
        type = "bookmark_operations",
        title = "Bookmark Operations"
      })
    end)
  elseif selected_item.action == "rename_bookmark" then
    -- Show bookmark selection menu for renaming
    vim.schedule(function()
      show_bookmark_selection_with_navigation({
        title = "Select Bookmark to Rename",
        filter = "local", -- Only local bookmarks can be renamed
        allow_toggle = false,
        on_select = function(bookmark)
          vim.ui.input({
            prompt = string.format("Enter new name for bookmark '%s': ", bookmark.display_name),
            default = bookmark.name
          }, function(new_name)
            if new_name == nil then
              -- User cancelled with Esc
              return
            end

            if new_name and new_name ~= "" and new_name ~= bookmark.name then
              if bookmark_commands.rename_bookmark(bookmark.name, new_name) then
                -- Refresh with latest data
                require('jj-nvim').refresh()
              end
            end
          end)
        end
      }, {
        type = "bookmark_operations",
        title = "Bookmark Operations"
      })
    end)
  elseif selected_item.action == "list_bookmarks" then
    -- Show bookmark selection menu for listing (read-only)
    vim.schedule(function()
      show_bookmark_selection_with_navigation({
        title = "All Bookmarks",
        filter = "local", -- Start with local, allow toggle
        allow_toggle = true,
        on_select = function(bookmark)
          -- Show bookmark action menu after current menu is fully closed
          vim.schedule(function()
            M.show_bookmark_action_menu(bookmark)
          end)
        end
      }, {
        type = "bookmark_operations",
        title = "Bookmark Operations"
      })
    end)
  end
end

-- Show bookmark action menu for a selected bookmark
M.show_bookmark_action_menu = function(bookmark)
  if not M.is_open() then
    vim.notify("JJ window is not open", vim.log.levels.WARN)
    return
  end

  -- Push current menu info to stack
  push_menu({
    type = "bookmark_selection",
    title = "All Bookmarks",
    filter = "local",
    allow_toggle = true
  })

  local bookmark_commands = require('jj-nvim.jj.bookmark_commands')
  local current_commit = navigation.get_current_commit(state.win_id)

  -- Build menu items based on bookmark type and status
  local menu_items = {}

  -- Show details
  table.insert(menu_items, {
    key = "d",
    description = "Show details",
    action = "show_details",
    data = { bookmark = bookmark }
  })

  -- Move bookmark (only for local bookmarks)
  if not bookmark.remote and current_commit then
    table.insert(menu_items, {
      key = "m",
      description = "Move to current commit",
      action = "move_bookmark",
      data = { bookmark = bookmark, target_commit = current_commit }
    })
  end

  -- Push bookmark (only for local bookmarks)
  if not bookmark.remote then
    table.insert(menu_items, {
      key = "p",
      description = "Push bookmark",
      action = "push_bookmark",
      data = { bookmark = bookmark }
    })
  end

  -- Push options (only for local bookmarks)
  if not bookmark.remote then
    table.insert(menu_items, {
      key = "P",
      description = "Push options",
      action = "push_options",
      data = { bookmark = bookmark }
    })
  end

  -- Delete bookmark (only for local bookmarks)
  if not bookmark.remote then
    table.insert(menu_items, {
      key = "x",
      description = "Delete bookmark",
      action = "delete_bookmark",
      data = { bookmark = bookmark }
    })
  end

  -- Forget bookmark (only for local bookmarks)
  if not bookmark.remote then
    table.insert(menu_items, {
      key = "f",
      description = "Forget bookmark",
      action = "forget_bookmark",
      data = { bookmark = bookmark }
    })
  end

  -- Track/untrack for remote bookmarks
  if bookmark.remote then
    -- Get all bookmarks to check if there's a corresponding local bookmark
    local all_bookmarks = bookmark_commands.get_all_bookmarks()
    local has_local_bookmark = false
    
    for _, b in ipairs(all_bookmarks) do
      if b.name == bookmark.name and not b.remote then
        has_local_bookmark = true
        break
      end
    end
    
    if has_local_bookmark then
      -- If there's a local bookmark, offer to untrack the remote
      table.insert(menu_items, {
        key = "u",
        description = "Untrack bookmark",
        action = "untrack_bookmark",
        data = { bookmark = bookmark }
      })
    else
      -- If there's no local bookmark, offer to track the remote
      table.insert(menu_items, {
        key = "t",
        description = "Track bookmark",
        action = "track_bookmark",
        data = { bookmark = bookmark }
      })
    end
  end

  local menu_config = {
    id = "bookmark_actions",
    title = "Bookmark: " .. bookmark.display_name,
    items = menu_items
  }

  -- Show the menu
  local success = inline_menu.show(state.win_id, menu_config, {
    on_select = function(selected_item)
      M.handle_bookmark_action(selected_item)
    end,
    parent_menu_callback = function()
      -- Go back to previous menu
      local prev_menu = pop_menu()
      if prev_menu and prev_menu.type == "bookmark_selection" then
        vim.schedule(function()
          M.show_bookmark_selection_menu({
            title = prev_menu.title,
            filter = prev_menu.filter,
            allow_toggle = prev_menu.allow_toggle,
            on_select = function(selected_bookmark)
              vim.schedule(function()
                M.show_bookmark_action_menu(selected_bookmark)
              end)
            end
          })
        end)
      end
    end,
    on_cancel = function()
      -- Clear menu stack completely on explicit cancel
      clear_menu_stack()
    end
  })

  return success
end

-- Handle bookmark action menu selections
M.handle_bookmark_action = function(selected_item)
  local bookmark_commands = require('jj-nvim.jj.bookmark_commands')
  local action = selected_item.action
  local data = selected_item.data

  if action == "show_details" then
    local bookmark = data.bookmark
    vim.schedule(function()
      M.show_bookmark_details_menu(bookmark)
    end)
  elseif action == "move_bookmark" then
    local bookmark = data.bookmark
    local target_commit = data.target_commit

    if bookmark.name and target_commit.id then
      bookmark_commands.move_bookmark(bookmark.name, target_commit.id, {
        on_success = function()
          -- Refresh the log to show updated bookmark position
          require('jj-nvim').refresh()
        end
      })
    end
  elseif action == "delete_bookmark" then
    local bookmark = data.bookmark

    if bookmark.name then
      vim.ui.select({ 'Yes', 'No' }, {
        prompt = string.format("Delete bookmark '%s'?", bookmark.name),
      }, function(choice)
        if choice == 'Yes' then
          if bookmark_commands.delete_bookmark(bookmark.name) then
            require('jj-nvim').refresh()
          end
        end
      end)
    end
  elseif action == "forget_bookmark" then
    local bookmark = data.bookmark

    if bookmark.name then
      vim.ui.select({ 'Yes', 'No' }, {
        prompt = string.format("Forget bookmark '%s'? This won't delete it on remotes.", bookmark.name),
      }, function(choice)
        if choice == 'Yes' then
          if bookmark_commands.forget_bookmark(bookmark.name) then
            require('jj-nvim').refresh()
          end
        end
      end)
    end
  elseif action == "push_bookmark" then
    local bookmark = data.bookmark

    if bookmark.name then
      bookmark_commands.push_bookmark(bookmark.name, {
        on_success = function()
          require('jj-nvim').refresh()
        end
      })
    end
  elseif action == "push_options" then
    local bookmark = data.bookmark
    vim.schedule(function()
      M.show_push_options_menu(bookmark)
    end)
  elseif action == "push_force" then
    local bookmark = data.bookmark

    if bookmark.name then
      vim.ui.select({ 'Yes', 'No' }, {
        prompt = string.format("Force push bookmark '%s'? This may overwrite remote changes.", bookmark.name),
      }, function(choice)
        if choice == 'Yes' then
          bookmark_commands.push_bookmark(bookmark.name, {
            force = true,
            on_success = function()
              require('jj-nvim').refresh()
            end
          })
        end
      end)
    end
  elseif action == "push_deleted" then
    local bookmark = data.bookmark

    if bookmark.name then
      vim.ui.select({ 'Yes', 'No' }, {
        prompt = string.format("Push deletion of bookmark '%s' to remote?", bookmark.name),
      }, function(choice)
        if choice == 'Yes' then
          bookmark_commands.push_bookmark(bookmark.name, {
            deleted = true,
            on_success = function()
              require('jj-nvim').refresh()
            end
          })
        end
      end)
    end
  elseif action == "push_dry_run" then
    local bookmark = data.bookmark

    if bookmark.name then
      bookmark_commands.push_bookmark(bookmark.name, {
        dry_run = true,
        on_success = function()
          -- No refresh needed for dry run
        end
      })
    end
  elseif action == "track_bookmark" then
    local bookmark = data.bookmark

    if bookmark.name and bookmark.remote then
      if bookmark_commands.track_bookmark(bookmark.name, bookmark.remote) then
        require('jj-nvim').refresh()
      end
    end
  elseif action == "untrack_bookmark" then
    local bookmark = data.bookmark

    if bookmark.name and bookmark.remote then
      if bookmark_commands.untrack_bookmark(bookmark.name, bookmark.remote) then
        require('jj-nvim').refresh()
      end
    end
  end
end

-- Show bookmark details in a menu format
M.show_bookmark_details_menu = function(bookmark)
  if not M.is_open() then
    vim.notify("JJ window is not open", vim.log.levels.WARN)
    return
  end

  -- Push current menu info to stack
  push_menu({
    type = "bookmark_actions",
    bookmark = bookmark
  })

  -- Build details as menu items (read-only display)
  local menu_items = {}

  table.insert(menu_items, {
    key = "1",
    description = "Name: " .. (bookmark.name or "unknown"),
    action = "noop",
    data = {}
  })

  table.insert(menu_items, {
    key = "2",
    description = "Type: " .. (bookmark.remote and ("remote@" .. bookmark.remote) or "local"),
    action = "noop",
    data = {}
  })

  if bookmark.commit_id then
    table.insert(menu_items, {
      key = "3",
      description = "Commit: " .. bookmark.commit_id,
      action = "noop",
      data = {}
    })
  end

  if bookmark.change_id then
    table.insert(menu_items, {
      key = "4",
      description = "Change: " .. bookmark.change_id,
      action = "noop",
      data = {}
    })
  end

  -- Status information
  local status_parts = {}
  if not bookmark.present then
    table.insert(status_parts, "deleted")
  end
  if bookmark.conflict then
    table.insert(status_parts, "conflict")
  end
  if bookmark.remote and bookmark.tracked then
    table.insert(status_parts, "tracked")
  elseif bookmark.remote then
    table.insert(status_parts, "untracked")
  end

  if #status_parts > 0 then
    table.insert(menu_items, {
      key = "5",
      description = "Status: " .. table.concat(status_parts, ", "),
      action = "noop",
      data = {}
    })
  end

  -- Tracking information for remote bookmarks
  if bookmark.remote and bookmark.tracked then
    if bookmark.tracking_ahead_count > 0 or bookmark.tracking_behind_count > 0 then
      table.insert(menu_items, {
        key = "6",
        description = string.format("Sync: %d ahead, %d behind",
          bookmark.tracking_ahead_count, bookmark.tracking_behind_count),
        action = "noop",
        data = {}
      })
    else
      table.insert(menu_items, {
        key = "6",
        description = "Sync: up to date",
        action = "noop",
        data = {}
      })
    end
  end

  -- Add back navigation item
  table.insert(menu_items, {
    key = "b",
    description = "← Back to bookmark actions",
    action = "back_to_actions",
    data = { bookmark = bookmark }
  })

  local menu_config = {
    id = "bookmark_details",
    title = "Details: " .. bookmark.display_name,
    items = menu_items
  }

  -- Show the menu
  local success = inline_menu.show(state.win_id, menu_config, {
    on_select = function(selected_item)
      if selected_item.action == "back_to_actions" then
        vim.schedule(function()
          M.show_bookmark_action_menu(selected_item.data.bookmark)
        end)
      end
      -- Other actions are noop for details display
    end,
    parent_menu_callback = function()
      -- Go back to previous menu
      local prev_menu = pop_menu()
      if prev_menu and prev_menu.type == "bookmark_actions" then
        vim.schedule(function()
          M.show_bookmark_action_menu(prev_menu.bookmark)
        end)
      end
    end,
    on_cancel = function()
      -- Clear menu stack completely on explicit cancel
      clear_menu_stack()
    end
  })

  return success
end

-- Show bookmark selection for squash target selection
M.show_squash_bookmark_selection = function()
  if not M.is_mode(MODES.TARGET_SELECT) then
    vim.notify("Not in target selection mode", vim.log.levels.WARN)
    return
  end

  local mode_data = select(2, M.get_mode())
  if not mode_data or mode_data.action ~= "squash" then
    vim.notify("Not in squash target selection mode", vim.log.levels.WARN)
    return
  end

  -- Store source commit before resetting mode
  local source_commit = mode_data.source_commit

  -- Reset mode and keymaps before showing bookmark menu
  M.reset_mode()
  M.setup_keymaps()

  -- Show bookmark selection menu
  M.show_bookmark_selection_menu({
    title = "Select Bookmark to Squash Into",
    filter = "local", -- Start with local bookmarks
    allow_toggle = true,
    on_select = function(bookmark)
      -- Show squash options menu for the selected bookmark with source commit
      actions.show_squash_options_menu(bookmark, "bookmark", state.win_id, source_commit)
    end,
    on_cancel = function()
      -- Return to target selection mode if bookmark selection is cancelled
      M.enter_target_selection_mode("squash", source_commit)
    end
  })
end

-- Show push options submenu for a bookmark
M.show_push_options_menu = function(bookmark)
  if not M.is_open() then
    vim.notify("JJ window is not open", vim.log.levels.WARN)
    return
  end

  local menu_items = {}

  -- Push normally (with smart confirmations)
  table.insert(menu_items, {
    key = "p",
    description = "Push normally",
    action = "push_bookmark",
    data = { bookmark = bookmark }
  })

  -- Push with force
  table.insert(menu_items, {
    key = "f",
    description = "Push with force (--force-with-lease)",
    action = "push_force",
    data = { bookmark = bookmark }
  })

  -- Push as deleted
  table.insert(menu_items, {
    key = "d",
    description = "Push as deleted (--deleted)",
    action = "push_deleted",
    data = { bookmark = bookmark }
  })

  -- Dry run preview
  table.insert(menu_items, {
    key = "r",
    description = "Dry run (preview changes)",
    action = "push_dry_run",
    data = { bookmark = bookmark }
  })

  local menu_config = {
    id = "push_options",
    title = "Push Options: " .. bookmark.display_name,
    items = menu_items
  }

  -- Show the menu
  local success = inline_menu.show(state.win_id, menu_config, {
    on_select = function(selected_item)
      M.handle_bookmark_action(selected_item)
    end,
    parent_menu_callback = function()
      -- Go back to bookmark action menu
      vim.schedule(function()
        M.show_bookmark_action_menu(bookmark)
      end)
    end,
    on_cancel = function()
      -- Go back to bookmark action menu
      vim.schedule(function()
        M.show_bookmark_action_menu(bookmark)
      end)
    end
  })

  if not success then
    vim.notify("Failed to show push options menu", vim.log.levels.ERROR)
  end
end

-- Get current window ID for external use
M.get_current_win_id = function()
  return state.win_id
end

-- Get selected commits for external use
M.get_selected_commits = function()
  return state.selected_commits or {}
end

-- Clear selections for external use
M.clear_selections = function()
  state.selected_commits = {}
  if state.buf_id and vim.api.nvim_buf_is_valid(state.buf_id) then
    local window_width = window_utils.get_width(state.win_id)
    buffer.update_status(state.buf_id, {
      selected_count = 0
    }, window_width)
    
    -- Update context window
    local context_window = require('jj-nvim.ui.context_window')
    local current_commit = navigation.get_current_commit(state.win_id)
    context_window.update(state.win_id, current_commit, {})
  end
end

-- Unified bookmark view renderer that works with the existing buffer system
M.render_unified_bookmark_view = function()
  if not state.win_id or not vim.api.nvim_win_is_valid(state.win_id) then
    return
  end
  
  local bookmark_commands = require('jj-nvim.jj.bookmark_commands')
  local buffer = require('jj-nvim.ui.buffer')
  local status = require('jj-nvim.ui.status')
  local window_utils = require('jj-nvim.utils.window')
  
  -- Get all bookmarks
  local bookmarks = bookmark_commands.get_all_bookmarks()
  if not bookmarks then
    bookmarks = {}
  end
  
  -- Filter out deleted/absent bookmarks since they're not valid targets
  local present_bookmarks = {}
  for _, bookmark in ipairs(bookmarks) do
    if bookmark.present then
      table.insert(present_bookmarks, bookmark)
    end
  end
  
  -- Update status state for bookmark view (count only present bookmarks)
  status.update_status({
    current_view = "bookmark",
    bookmark_count = #present_bookmarks
  })
  
  -- Get window width for rendering
  local window_width = window_utils.get_width(state.win_id)
  local raw_width = window_width
  local effective_width = raw_width - 2  -- Account for gutter columns
  
  -- Generate status lines
  local status_lines = status.build_status_content(raw_width)
  local status_height = #status_lines
  
  -- Build bookmark content lines
  local bookmark_lines = {}
  
  if #present_bookmarks == 0 then
    -- Empty state
    table.insert(bookmark_lines, "")
    table.insert(bookmark_lines, "No bookmarks found")
    table.insert(bookmark_lines, "")
    table.insert(bookmark_lines, "Create bookmarks with:")
    table.insert(bookmark_lines, "  jj bookmark create <name>")
    table.insert(bookmark_lines, "")
  else
    -- Format each present bookmark in jj's native style
    for i, bookmark in ipairs(present_bookmarks) do
      -- Build bookmark name with remote suffix
      local bookmark_name = bookmark.name
      if bookmark.remote then
        bookmark_name = bookmark_name .. "@" .. bookmark.remote
      end
      
      -- Add asterisk for divergent local bookmarks  
      if not bookmark.remote and bookmark.has_divergence then
        bookmark_name = bookmark_name .. "*"
      end
      
      local line_parts = {}
      table.insert(line_parts, bookmark_name)
      
      -- Add change ID if present (no arrow, just the ID)
      if bookmark.present and bookmark.change_id and bookmark.change_id ~= "no_change_id" then
        table.insert(line_parts, bookmark.change_id)
      elseif not bookmark.present then
        table.insert(line_parts, "(absent)")
      end
      
      -- Add status indicators
      local status_parts = {}
      if bookmark.conflict then
        table.insert(status_parts, "conflict")
      end
      if bookmark.tracked and (bookmark.tracking_ahead_count > 0 or bookmark.tracking_behind_count > 0) then
        local ahead = bookmark.tracking_ahead_count > 0 and ("+" .. bookmark.tracking_ahead_count) or ""
        local behind = bookmark.tracking_behind_count > 0 and ("-" .. bookmark.tracking_behind_count) or ""
        local tracking_status = ahead .. behind
        if tracking_status ~= "" then
          table.insert(status_parts, tracking_status)
        end
      end
      
      if #status_parts > 0 then
        table.insert(line_parts, "(" .. table.concat(status_parts, ", ") .. ")")
      end
      
      local display_line = table.concat(line_parts, " ")
      table.insert(bookmark_lines, display_line)
      
      -- Store positioning metadata for unified content interface
      local line_position = #bookmark_lines + status_height  -- Account for status lines
      bookmark.line_number = line_position
      bookmark.line_start = line_position  -- Single-line bookmark, start = end
      bookmark.line_end = line_position
      bookmark.header_line = line_position  -- For navigation consistency
      bookmark.display_line = display_line
      
      -- Mark as bookmark type for interface compatibility
      bookmark.content_type = "bookmark"
    end
    
    table.insert(bookmark_lines, "")
    table.insert(bookmark_lines, "Press Ctrl+T or Tab to toggle back to log view")
  end
  
  -- Store bookmark data for selection logic (only present bookmarks)
  state.bookmark_data = present_bookmarks
  
  -- Use the unified buffer rendering system
  vim.api.nvim_buf_set_option(state.buf_id, 'modifiable', true)
  vim.api.nvim_buf_set_option(state.buf_id, 'readonly', false)
  
  -- Clear existing content and highlights
  vim.api.nvim_buf_clear_namespace(state.buf_id, -1, 0, -1)
  
  -- Build final content: status lines + bookmark lines
  local final_lines = {}
  
  -- Add status lines
  for _, status_line in ipairs(status_lines) do
    table.insert(final_lines, status_line)
  end
  
  -- Add bookmark content
  for _, bookmark_line in ipairs(bookmark_lines) do
    table.insert(final_lines, bookmark_line)
  end
  
  -- Set buffer content
  vim.api.nvim_buf_set_lines(state.buf_id, 0, -1, false, final_lines)
  
  -- Apply status highlighting
  status.apply_status_highlighting(state.buf_id, status_height)
  
  -- Apply bookmark highlighting
  M.setup_bookmark_highlighting(status_height)
  
  -- Apply selection highlighting for any selected bookmarks
  M.update_bookmark_selection_display()
  
  -- Restore buffer settings
  vim.api.nvim_buf_set_option(state.buf_id, 'modifiable', false)
  vim.api.nvim_buf_set_option(state.buf_id, 'readonly', true)
end

-- Setup bookmark highlighting with status offset
M.setup_bookmark_highlighting = function(status_height)
  if not state.buf_id or not vim.api.nvim_buf_is_valid(state.buf_id) then
    return
  end
  
  -- Create namespace for bookmark highlighting
  local ns_id = vim.api.nvim_create_namespace('jj_bookmark_view')
  vim.api.nvim_buf_clear_namespace(state.buf_id, ns_id, 0, -1)
  
  -- Set up bookmark-specific highlight groups (theme-aware)
  -- Using colors that match the log view (bold purple for all bookmarks)
  local themes = require('jj-nvim.ui.themes')
  local theme = themes.get_theme()
  
  -- All bookmarks: bold purple (matches log view exactly)
  vim.api.nvim_set_hl(0, 'JJBookmarkName', { fg = theme.colors.magenta, bold = true })
  -- Change IDs: blue (consistent with commit IDs)
  vim.api.nvim_set_hl(0, 'JJBookmarkChangeId', { fg = theme.colors.bright_blue })
  -- Status indicators: yellow
  vim.api.nvim_set_hl(0, 'JJBookmarkStatus', { fg = theme.colors.yellow })
  -- Tracking info: bright_black (subtle)
  vim.api.nvim_set_hl(0, 'JJBookmarkTracking', { fg = theme.colors.bright_black })
  
  -- Apply syntax highlighting to bookmark lines (offset by status_height)
  status_height = status_height or 0
  
  -- Apply highlighting to each bookmark line
  if state.bookmark_data then
    for i, bookmark in ipairs(state.bookmark_data) do
      local line_nr = status_height + i - 1  -- 0-based line indexing
      local line_content = vim.api.nvim_buf_get_lines(state.buf_id, line_nr, line_nr + 1, false)[1]
      
      if line_content then
        M.apply_bookmark_line_highlighting(line_nr, line_content, bookmark)
      end
    end
  end
end

-- Apply highlighting to a specific bookmark line
M.apply_bookmark_line_highlighting = function(line_nr, line_content, bookmark)
  local ns_id = vim.api.nvim_create_namespace('jj_bookmark_view')
  local col = 0
  
  -- Highlight bookmark name (including @remote suffix if present)
  local bookmark_name = bookmark.name
  if bookmark.remote then
    bookmark_name = bookmark_name .. "@" .. bookmark.remote
  end
  if not bookmark.remote and bookmark.has_divergence then
    bookmark_name = bookmark_name .. "*"
  end
  
  local bookmark_end = col + #bookmark_name
  -- All bookmarks use the same color (bold purple like in log view)
  vim.api.nvim_buf_add_highlight(state.buf_id, ns_id, 'JJBookmarkName', line_nr, col, bookmark_end)
  col = bookmark_end
  
  -- Skip space
  if line_content:sub(col + 1, col + 1) == " " then
    col = col + 1
  end
  
  -- Highlight change ID
  if bookmark.change_id and bookmark.change_id ~= "no_change_id" then
    local change_id_start = col
    local change_id_end = col + #bookmark.change_id
    vim.api.nvim_buf_add_highlight(state.buf_id, ns_id, 'JJBookmarkChangeId', line_nr, change_id_start, change_id_end)
    col = change_id_end
  elseif not bookmark.present then
    -- Highlight "(absent)" status
    local absent_start = line_content:find("%(absent%)", col)
    if absent_start then
      local absent_end = absent_start + 8  -- length of "(absent)"
      vim.api.nvim_buf_add_highlight(state.buf_id, ns_id, 'JJBookmarkStatus', line_nr, absent_start - 1, absent_end)
    end
  end
  
  -- Highlight status indicators like (conflict, +2-1)
  local status_start = line_content:find("%(", col)
  if status_start then
    local status_end = line_content:find("%)", status_start)
    if status_end then
      vim.api.nvim_buf_add_highlight(state.buf_id, ns_id, 'JJBookmarkTracking', line_nr, status_start - 1, status_end)
    end
  end
end

-- Update bookmark selection display
M.update_bookmark_selection_display = function()
  if state.current_view ~= VIEW_TYPES.BOOKMARK or not state.bookmark_data then
    return
  end
  
  -- Create namespace for bookmark selection highlighting
  local ns_id = vim.api.nvim_create_namespace('jj_bookmark_selection')
  vim.api.nvim_buf_clear_namespace(state.buf_id, ns_id, 0, -1)
  
  local themes = require('jj-nvim.ui.themes')
  local selection_bg = themes.get_selection_color('background')
  
  -- Highlight bookmarks whose target commits are selected
  for _, bookmark in ipairs(state.bookmark_data) do
    if bookmark.commit_id and bookmark.line_number then
      for _, selected_id in ipairs(state.selected_commits) do
        if selected_id == bookmark.commit_id then
          -- Highlight the entire line
          vim.api.nvim_buf_add_highlight(state.buf_id, ns_id, 'JJSelectedCommitBg', 
                                        bookmark.line_number - 1, 0, -1)
          break
        end
      end
    end
  end
end

-- Toggle bookmark selection (adds bookmark's target commit to selected_commits)
M.toggle_bookmark_selection = function()
  if state.current_view ~= VIEW_TYPES.BOOKMARK then
    return false
  end
  
  -- Get current cursor position
  local cursor = vim.api.nvim_win_get_cursor(state.win_id)
  local line_number = cursor[1]
  
  -- Find the bookmark at this line
  if not state.bookmark_data then
    return false
  end
  
  local selected_bookmark = nil
  for _, bookmark in ipairs(state.bookmark_data) do
    if bookmark.line_number == line_number then
      selected_bookmark = bookmark
      break
    end
  end
  
  if not selected_bookmark or not selected_bookmark.commit_id then
    return false
  end
  
  -- Toggle selection using the bookmark's target commit ID
  local commit_id = selected_bookmark.commit_id
  local was_selected = false
  
  -- Check if this commit is already selected and remove it
  for i = #state.selected_commits, 1, -1 do
    if state.selected_commits[i] == commit_id then
      table.remove(state.selected_commits, i)
      was_selected = true
      break
    end
  end
  
  -- If not selected, add it
  if not was_selected then
    table.insert(state.selected_commits, commit_id)
  end
  
  -- Update visual display
  M.update_bookmark_selection_display()
  
  return true
end

-- Get current view type
M.get_current_view = function()
  return state.current_view
end

-- Get bookmark data for navigation
M.get_bookmark_data = function()
  return state.bookmark_data
end

return M
