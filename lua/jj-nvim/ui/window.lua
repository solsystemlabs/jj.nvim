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

local state = {
  win_id = nil,
  buf_id = nil,
  mode = MODES.NORMAL,
  mode_data = {},        -- Mode-specific data storage
  selected_commits = {}, -- For multi-select mode
}

-- Helper function to setup border highlight group
local function setup_border_highlight()
  local border_color = config.get('window.border.color')
  local theme_name = config.get('colors.theme') or 'auto'

  -- Auto-detect theme if set to 'auto'
  if theme_name == 'auto' then
    theme_name = themes.detect_theme()
  end

  local hex_color = themes.get_border_color(border_color, theme_name)

  -- Create a highlight group for the border
  vim.api.nvim_set_hl(0, 'JJBorder', { fg = hex_color })
end

-- Helper function to get border configuration
local function get_border_config()
  local border_enabled = config.get('window.border.enabled')
  local border_style = config.get('window.border.style')

  if not border_enabled then
    return 'none'
  end

  -- Setup the border highlight
  setup_border_highlight()

  if border_style == 'single' then
    return 'single'
  elseif border_style == 'double' then
    return 'double'
  elseif border_style == 'rounded' then
    return 'rounded'
  elseif border_style == 'thick' then
    return { '█', '█', '█', '█', '█', '█', '█', '█' }
  elseif border_style == 'shadow' then
    return { ' ', ' ', ' ', ' ', ' ', ' ', ' ', ' ' }
  elseif border_style == 'left' then
    -- Left-only border: top-left, top, top-right, right, bottom-right, bottom, bottom-left, left
    return { '', '', '', '', '', '', '', '│' }
  else
    return border_style -- Allow custom border styles
  end
end

-- Helper function to create window configuration
local function create_window_config()
  local width = config.get('window.width')
  local position = config.get('window.position')

  local win_width = vim.api.nvim_get_option('columns')
  local win_height = vim.api.nvim_get_option('lines')

  local col = position == 'left' and 0 or (win_width - width)

  return {
    relative = 'editor',
    width = width,
    height = win_height - 2,
    col = col,
    row = 0,
    style = 'minimal',
    border = get_border_config(),
  }
end

-- Helper function to configure window and buffer display options
local function setup_window_display()
  vim.api.nvim_win_set_option(state.win_id, 'wrap', config.get('window.wrap'))
  vim.api.nvim_win_set_option(state.win_id, 'cursorline', true)

  -- Set border highlight if border is enabled
  local border_enabled = config.get('window.border.enabled')
  if border_enabled then
    vim.api.nvim_win_set_option(state.win_id, 'winhighlight', 'FloatBorder:JJBorder')
  else
    vim.api.nvim_win_set_option(state.win_id, 'winhighlight', '')
  end

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
  state.win_id = vim.api.nvim_open_win(state.buf_id, true, create_window_config())

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
  state.win_id = vim.api.nvim_open_win(state.buf_id, true, create_window_config())

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

  local opts = { noremap = true, silent = true, buffer = state.buf_id }

  -- Basic window controls
  vim.keymap.set('n', 'q', function() M.close() end, opts)
  vim.keymap.set('n', '<Esc>', function() M.close() end, opts)

  -- Override cursor movement to prevent going into status area
  vim.keymap.set('n', 'k', function()
    local cursor = vim.api.nvim_win_get_cursor(state.win_id)
    local current_line = cursor[1]
    local window_width = window_utils.get_width(state.win_id)
    local status_height = buffer.get_status_height(window_width)

    -- Only move up if not at the boundary (first line after status box)
    if current_line > status_height + 1 then
      vim.api.nvim_win_set_cursor(state.win_id, { current_line - 1, 0 })
    end
  end, opts)

  vim.keymap.set('n', '<Up>', function()
    local cursor = vim.api.nvim_win_get_cursor(state.win_id)
    local current_line = cursor[1]
    local window_width = window_utils.get_width(state.win_id)
    local status_height = buffer.get_status_height(window_width)

    -- Only move up if not at the boundary (first line after status box)
    if current_line > status_height + 1 then
      vim.api.nvim_win_set_cursor(state.win_id, { current_line - 1, 0 })
    end
  end, opts)

  -- Smart commit navigation (replaces basic j/k)
  vim.keymap.set('n', 'j', function()
    navigation.next_commit(state.win_id)
  end, opts)
  vim.keymap.set('n', 'k', function()
    navigation.prev_commit(state.win_id)
  end, opts)

  -- Additional navigation
  vim.keymap.set('n', 'J', function()
    navigation.next_commit_centered(state.win_id)
  end, opts)
  vim.keymap.set('n', 'K', function()
    navigation.prev_commit_centered(state.win_id)
  end, opts)

  -- Go to specific commits
  vim.keymap.set('n', 'gg', function()
    navigation.goto_first_commit(state.win_id)
  end, opts)
  vim.keymap.set('n', 'G', function()
    navigation.goto_last_commit(state.win_id)
  end, opts)
  vim.keymap.set('n', '@', function()
    navigation.goto_current_commit(state.win_id)
  end, opts)

  -- Snap to commit header if cursor is on a description line
  vim.keymap.set('n', '<Space>', function()
    local commit = navigation.get_current_commit(state.win_id)
    if commit then
      state.selected_commits = multi_select.toggle_commit_selection(commit, state.selected_commits)
      -- Update highlighting to reflect selection changes
      M.highlight_current_commit()
      -- Update status display with current selection count only
      local window_width = window_utils.get_width(state.win_id)
      buffer.update_status(state.buf_id, {
        selected_count = #state.selected_commits
      }, window_width)
    else
      -- Update status to show selection count as 0
      local window_width = window_utils.get_width(state.win_id)
      buffer.update_status(state.buf_id, {
        selected_count = 0
      }, window_width)
    end
  end, opts)

  -- Actions on commits
  -- Show diff for current commit
  vim.keymap.set('n', '<CR>', function()
    local commit = navigation.get_current_commit(state.win_id)
    actions.show_diff(commit)
  end, opts)

  -- Show diff (alternative binding)
  vim.keymap.set('n', 'd', function()
    local commit = navigation.get_current_commit(state.win_id)
    actions.show_diff(commit, 'git')
  end, opts)

  -- Show diff summary/stats
  vim.keymap.set('n', 'D', function()
    local commit = navigation.get_current_commit(state.win_id)
    actions.show_diff_summary(commit)
  end, opts)

  -- Edit commit
  vim.keymap.set('n', 'e', function()
    local commit = navigation.get_current_commit(state.win_id)
    if actions.edit_commit(commit) then
      -- Refresh with latest data
      require('jj-nvim').refresh()
    end
  end, opts)

  -- Set description for commit
  vim.keymap.set('n', 'm', function()
    local commit = navigation.get_current_commit(state.win_id)
    actions.set_description(commit, function()
      -- Refresh with latest data
      require('jj-nvim').refresh()
    end)
  end, opts)

  -- Abandon commit(s)
  vim.keymap.set('n', 'a', function()
    if #state.selected_commits > 0 then
      -- Abandon selected commits
      actions.abandon_multiple_commits(state.selected_commits, function()
        -- Clear selections after abandoning
        state.selected_commits = {}
        -- Refresh with latest data
        require('jj-nvim').refresh()
        -- Update status display to reflect cleared selections
        local window_width = window_utils.get_width(state.win_id)
        buffer.update_status(state.buf_id, {
          selected_count = #state.selected_commits
        }, window_width)
      end)
    else
      -- Abandon current commit
      local commit = navigation.get_current_commit(state.win_id)
      if commit then
        actions.abandon_commit(commit, function()
          -- Refresh with latest data
          require('jj-nvim').refresh()
        end)
      else
        vim.notify("No commit under cursor to abandon", vim.log.levels.WARN)
      end
    end
  end, opts)

  -- Bookmark operations
  vim.keymap.set('n', 'b', function()
    M.show_bookmark_menu()
  end, opts)

  -- Explicit multi-abandon (abandon all selected commits)
  vim.keymap.set('n', 'A', function()
    if #state.selected_commits > 0 then
      actions.abandon_multiple_commits(state.selected_commits, function()
        -- Clear selections after abandoning
        state.selected_commits = {}
        -- Refresh with latest data
        require('jj-nvim').refresh()
        -- Update status display to reflect cleared selections
        local window_width = window_utils.get_width(state.win_id)
        buffer.update_status(state.buf_id, {
          selected_count = #state.selected_commits
        }, window_width)
      end)
    else
      vim.notify("No commits selected for multi-abandon", vim.log.levels.WARN)
    end
  end, opts)

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
      -- Update highlighting to reflect cleared selections
      M.highlight_current_commit()
      -- Update status display to reflect cleared selections
      local window_width = window_utils.get_width(state.win_id)
      buffer.update_status(state.buf_id, {
        selected_count = #state.selected_commits
      }, window_width)
    else
      -- No selections to clear, close the window (normal Esc behavior)
      M.close()
    end
  end, opts)

  -- Toggle description expansion
  vim.keymap.set('n', '<Tab>', function()
    M.toggle_description_expansion()
  end, opts)

  -- New change creation (simple)
  vim.keymap.set('n', 'n', function()
    -- Get current commit for context
    local current_commit = navigation.get_current_commit(state.win_id)
    if not current_commit then
      vim.notify("No commit found at cursor position", vim.log.levels.WARN)
      return
    end

    vim.ui.input({ prompt = "Change description (Enter for none): " }, function(description)
      if description == nil then
        -- User cancelled with Esc
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
    M.show_new_change_menu()
  end, opts)

  -- Buffer refresh
  vim.keymap.set('n', 'R', function()
    vim.notify("Refreshing commits...", vim.log.levels.INFO)
    require('jj-nvim').refresh()
  end, opts)

  -- Window width adjustment keybinds
  vim.keymap.set('n', '+', function() M.adjust_width(WIDTH_ADJUSTMENTS.LARGE) end, opts)
  vim.keymap.set('n', '-', function() M.adjust_width(-WIDTH_ADJUSTMENTS.LARGE) end, opts)
  vim.keymap.set('n', '=', function() M.adjust_width(WIDTH_ADJUSTMENTS.SMALL) end, opts)
  vim.keymap.set('n', '_', function() M.adjust_width(-WIDTH_ADJUSTMENTS.SMALL) end, opts)

  -- Git operations
  vim.keymap.set('n', 'f', function()
    actions.git_fetch()
  end, opts)

  vim.keymap.set('n', 'p', function()
    actions.git_push()
  end, opts)

  -- Repository status
  vim.keymap.set('n', 'S', function()
    actions.show_status()
  end, opts)

  -- Commit working copy changes
  vim.keymap.set('n', 'c', function()
    actions.commit_working_copy({}, function()
      -- Refresh with latest data
      require('jj-nvim').refresh()
    end)
  end, opts)

  -- Commit with options menu
  vim.keymap.set('n', 'C', function()
    actions.show_commit_menu(state.win_id)
  end, opts)

  -- Help dialog
  vim.keymap.set('n', '?', function()
    help.show(state.win_id)
  end, opts)
end

-- Setup keymaps for target selection mode
M.setup_target_selection_keymaps = function()
  if not state.buf_id then return end

  local opts = { noremap = true, silent = true, buffer = state.buf_id }

  -- Override Enter and Escape for target selection
  vim.keymap.set('n', '<CR>', function() M.confirm_target_selection() end, opts)
  vim.keymap.set('n', '<Esc>', function() M.cancel_target_selection() end, opts)

  -- Setup common navigation keymaps
  keymaps.setup_common_navigation(state.buf_id, state.win_id, navigation, opts)

  -- Disable other actions during target selection
  keymaps.setup_disabled_actions(state.buf_id, "Press Esc to cancel target selection", opts)
end

-- Setup keymaps for multi-select mode
M.setup_multi_select_keymaps = function()
  if not state.buf_id then return end

  -- First, explicitly remove conflicting keymaps
  keymaps.clear_conflicting_keymaps(state.buf_id)

  local opts = { noremap = true, silent = true, buffer = state.buf_id }

  -- Space to toggle commit selection
  vim.keymap.set('n', '<Space>', function() M.toggle_commit_selection() end, opts)

  -- Enter to confirm selection and create merge commit
  vim.keymap.set('n', '<CR>', function() M.confirm_multi_selection() end, opts)

  -- Escape to cancel multi-select mode
  vim.keymap.set('n', '<Esc>', function() M.cancel_multi_selection() end, opts)

  -- Setup common navigation keymaps with update callback
  keymaps.setup_common_navigation(state.buf_id, state.win_id, navigation, opts, M.update_multi_select_display)

  -- Disable other actions during multi-select mode
  keymaps.setup_disabled_actions(state.buf_id, "Press Esc to cancel multi-selection, Enter to confirm", opts)
end

M.adjust_width = function(delta)
  if not M.is_open() then return end

  local current_width = window_utils.get_width(state.win_id)
  local new_width = math.max(WINDOW_CONSTRAINTS.MIN_WIDTH, math.min(WINDOW_CONSTRAINTS.MAX_WIDTH, current_width + delta))

  -- Update the window width
  vim.api.nvim_win_set_width(state.win_id, new_width)

  -- Update the position if it's on the right side
  local position = config.get('window.position')
  local border = get_border_config()

  if position == 'right' then
    local win_width = vim.api.nvim_get_option('columns')
    local new_col = win_width - new_width
    vim.api.nvim_win_set_config(state.win_id, {
      relative = 'editor',
      width = new_width,
      height = vim.api.nvim_win_get_height(state.win_id),
      col = new_col,
      row = 0,
      border = border,
    })
  else
    vim.api.nvim_win_set_config(state.win_id, {
      relative = 'editor',
      width = new_width,
      height = vim.api.nvim_win_get_height(state.win_id),
      col = 0,
      row = 0,
      border = border,
    })
  end

  -- Save the new width persistently
  config.set('window.width', new_width)

  -- Refresh with latest data to apply new wrapping
  require('jj-nvim').refresh()
end

-- Function to highlight the current commit (extracted for reuse)
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

  -- Get the commit at this line (using proper offset conversion)
  local commit = buffer.get_current_commit(state.buf_id)
  local cursor_commit_id = nil
  if commit then
    cursor_commit_id = commit.change_id or commit.short_change_id
  end

  -- Apply multi-select highlighting first for all selected commits EXCEPT the one under cursor
  if #state.selected_commits > 0 then
    local commits = buffer.get_commits(state.buf_id)
    if commits then
      local window_width = window_utils.get_width(state.win_id)
      -- Filter out the commit under cursor to avoid duplicate highlighting
      local filtered_selected = {}
      for _, selected_id in ipairs(state.selected_commits) do
        if selected_id ~= cursor_commit_id then
          table.insert(filtered_selected, selected_id)
        end
      end
      multi_select.highlight_selected_commits(state.buf_id, commits, filtered_selected, window_width)
    end
  end

  -- Apply cursor highlighting only to the commit under cursor
  if not commit then return end

  if commit.line_start and commit.line_end then
    local window_width = window_utils.get_width(state.win_id)

    -- Check if this commit is selected
    local is_selected_commit = false
    if state.selected_commits then
      for _, selected_id in ipairs(state.selected_commits) do
        if selected_id == cursor_commit_id then
          is_selected_commit = true
          break
        end
      end
    end

    -- Choose highlight group based on current mode and selection status
    local highlight_group
    if M.is_mode(MODES.TARGET_SELECT) then
      highlight_group = 'JJTargetSelection'
    elseif is_selected_commit then
      highlight_group = 'JJSelectedCommitCursor' -- Special highlight for selected commit under cursor
    else
      highlight_group = 'JJCommitSelected'
    end

    -- Convert log line numbers to display line numbers for highlighting
    local display_start = buffer.get_display_line_number(commit.line_start, window_width)
    local display_end = buffer.get_display_line_number(commit.line_end, window_width)

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

  -- Define highlight groups for selected commit
  vim.api.nvim_set_hl(0, 'JJCommitSelected', { bg = '#3c3836' })                               -- Dark background for normal selection
  vim.api.nvim_set_hl(0, 'JJTargetSelection', { bg = '#1d2021', fg = '#fb4934', bold = true }) -- Red background for target selection
  vim.api.nvim_set_hl(0, 'JJSelectedCommitCursor', { bg = '#5a5a5a' })                         -- Lighter background for selected commit under cursor

  -- Set up autocmd to highlight on cursor movement
  vim.api.nvim_create_autocmd({ 'CursorMoved', 'CursorMovedI' }, {
    buffer = state.buf_id,
    callback = M.highlight_current_commit,
    group = vim.api.nvim_create_augroup('JJCommitHighlight_' .. state.buf_id, { clear = true })
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
M.enter_target_selection_mode = function(action_type)
  if not M.is_open() then
    vim.notify("JJ window is not open", vim.log.levels.WARN)
    return
  end

  -- Store current cursor position to return to if cancelled
  local current_line = vim.api.nvim_win_get_cursor(state.win_id)[1]

  M.set_mode(MODES.TARGET_SELECT, {
    action = action_type, -- "after" or "before"
    original_line = current_line
  })

  -- Update keymaps for target selection
  M.setup_target_selection_keymaps()

  -- Show status message
  local action_desc = action_type == "after" and "after" or "before"
  vim.notify(string.format("Select commit to insert %s (Enter to confirm, Esc to cancel)", action_desc),
    vim.log.levels.INFO)
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
  elseif action_type == "before" then
    success = actions.new_before(target_commit)
  end

  if success then
    require('jj-nvim').refresh()
  end

  -- Return to normal mode
  M.reset_mode()
  M.setup_keymaps() -- Restore normal keymaps
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

  -- Return to normal mode
  M.reset_mode()
  M.setup_keymaps() -- Restore normal keymaps

  vim.notify("Target selection cancelled", vim.log.levels.INFO)
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
      M.setup_keymaps() -- Restore normal keymaps
    else
      vim.notify("Merge commit creation cancelled", vim.log.levels.INFO)
    end
  end)
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
  local success = buffer.update_from_commits(state.buf_id, commits, buffer.get_mode())

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
    buffer.update_from_commits(state.buf_id, all_commits, buffer.get_mode())
  end
end

-- Show bookmark selection menu
M.show_bookmark_selection_menu = function(options)
  options = options or {}
  local filter_type = options.filter or "local"  -- "local", "remote", "all"
  local title = options.title or "Select Bookmark"
  local on_select = options.on_select
  local allow_toggle = options.allow_toggle ~= false  -- Default to true
  
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
  
  local bookmarks = bookmark_commands.get_bookmarks(bookmark_options)
  if not bookmarks then
    vim.notify("Failed to load bookmarks", vim.log.levels.ERROR)
    return false
  end
  
  -- Filter bookmarks by type
  local filtered_bookmarks = {}
  for _, bookmark in ipairs(bookmarks) do
    if filter_type == "local" and (bookmark.type == "local" or bookmark.type == "conflicted") then
      table.insert(filtered_bookmarks, bookmark)
    elseif filter_type == "remote" and bookmark.type == "remote" then
      table.insert(filtered_bookmarks, bookmark)
    elseif filter_type == "all" then
      table.insert(filtered_bookmarks, bookmark)
    end
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
      if a.target_commit and a.target_commit.id then
        a_is_current = a.target_commit.id == current_commit_id or 
                      a.target_commit.id:find("^" .. current_commit_id) or
                      current_commit_id:find("^" .. a.target_commit.id)
      end
      if b.target_commit and b.target_commit.id then
        b_is_current = b.target_commit.id == current_commit_id or 
                      b.target_commit.id:find("^" .. current_commit_id) or
                      current_commit_id:find("^" .. b.target_commit.id)
      end
    end
    
    -- Current commit bookmarks come first
    if a_is_current and not b_is_current then
      return true
    elseif not a_is_current and b_is_current then
      return false
    else
      -- Both are current or both are not current: sort alphabetically
      return a:get_display_name() < b:get_display_name()
    end
  end)
  
  -- Build menu items
  local menu_items = {}
  for i, bookmark in ipairs(filtered_bookmarks) do
    local description = bookmark:get_display_name()
    
    -- Add indicator if bookmark is on current commit
    if current_commit_id and bookmark.target_commit and bookmark.target_commit.id then
      local is_current = bookmark.target_commit.id == current_commit_id or 
                        bookmark.target_commit.id:find("^" .. current_commit_id) or
                        current_commit_id:find("^" .. bookmark.target_commit.id)
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
  
  -- Add toggle option if enabled
  if allow_toggle then
    local toggle_desc = ""
    if filter_type == "local" then
      toggle_desc = "t - Show remote bookmarks"
    elseif filter_type == "remote" then
      toggle_desc = "t - Show local bookmarks"
    else
      toggle_desc = "t - Show local only"
    end
    
    table.insert(menu_items, {
      key = "t",
      description = toggle_desc,
      action = "toggle_filter",
      data = { current_filter = filter_type, options = options }
    })
  end
  
  local menu_config = {
    id = "bookmark_selection",
    title = title,
    items = menu_items
  }
  
  -- Show the menu
  local success = inline_menu.show(state.win_id, menu_config, {
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
        
        local new_options = vim.tbl_deep_extend("force", selected_item.data.options, { filter = new_filter })
        M.show_bookmark_selection_menu(new_options)
      end
    end,
    on_cancel = function()
      -- Menu closed without selection
    end
  })
  
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
      -- Menu closed without selection
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
          -- Clear cache and refresh with latest data
          bookmark_commands.clear_cache()
          require('jj-nvim').refresh()
        end
      end
    end)
    
  elseif selected_item.action == "delete_bookmark" then
    -- Show bookmark selection menu for deletion (with small delay to ensure first menu is closed)
    vim.schedule(function()
      M.show_bookmark_selection_menu({
        title = "Select Bookmark to Delete",
        filter = "local",  -- Only local bookmarks can be deleted
        allow_toggle = false,  -- No need to toggle for delete
        on_select = function(bookmark)
          -- Confirm deletion
          vim.ui.select({ 'Yes', 'No' }, {
            prompt = string.format("Delete bookmark '%s'?", bookmark:get_display_name()),
          }, function(choice)
            if choice == 'Yes' then
              if bookmark_commands.delete_bookmark(bookmark.name) then
                -- Clear cache and refresh with latest data
                bookmark_commands.clear_cache()
                require('jj-nvim').refresh()
              end
            end
          end)
        end
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
      M.show_bookmark_selection_menu({
        title = "Select Bookmark to Move Here",
        filter = "local",  -- Only local bookmarks can be moved
        allow_toggle = false,
        on_select = function(bookmark)
          local target_revision = target_commit.change_id or target_commit.short_change_id
          
          if bookmark_commands.move_bookmark(bookmark.name, target_revision) then
            -- Clear cache and refresh with latest data
            bookmark_commands.clear_cache()
            require('jj-nvim').refresh()
          end
        end
      })
    end)
    
  elseif selected_item.action == "rename_bookmark" then
    -- Show bookmark selection menu for renaming
    vim.schedule(function()
      M.show_bookmark_selection_menu({
        title = "Select Bookmark to Rename",
        filter = "local",  -- Only local bookmarks can be renamed
        allow_toggle = false,
        on_select = function(bookmark)
          vim.ui.input({ 
            prompt = string.format("Enter new name for bookmark '%s': ", bookmark:get_display_name()),
            default = bookmark.name
          }, function(new_name)
            if new_name == nil then
              -- User cancelled with Esc
              return
            end
            
            if new_name and new_name ~= "" and new_name ~= bookmark.name then
              if bookmark_commands.rename_bookmark(bookmark.name, new_name) then
                -- Clear cache and refresh with latest data
                bookmark_commands.clear_cache()
                require('jj-nvim').refresh()
              end
            end
          end)
        end
      })
    end)
    
  elseif selected_item.action == "list_bookmarks" then
    -- Show bookmark selection menu for listing (read-only)
    vim.schedule(function()
      M.show_bookmark_selection_menu({
        title = "All Bookmarks",
        filter = "local",  -- Start with local, allow toggle
        allow_toggle = true,
        on_select = function(bookmark)
          -- Just show bookmark details
          local details = string.format("Bookmark: %s\nType: %s\nTarget: %s\nMessage: %s",
            bookmark:get_display_name(),
            bookmark.type,
            bookmark.target_commit.id:sub(1, 8),
            bookmark.target_commit.message or "")
          vim.notify(details, vim.log.levels.INFO)
        end
      })
    end)
  end
end

return M
