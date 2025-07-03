local M = {}

local config = require('jj-nvim.config')
local action_menu = require('jj-nvim.ui.action_menu')

-- Context window state
local context_state = {
  enabled = false,
  win_id = nil,
  buf_id = nil,
  parent_win_id = nil,
  last_selection_count = 0,
  last_context = "",
}

-- Create floating window for context
local function create_context_window(parent_win_id, initial_content_lines)
  -- Get configuration
  local ctx_config = config.get('context_window') or {}
  local position = ctx_config.position or 'bottom'
  local height_pct = ctx_config.height or 0.3
  local width_pct = ctx_config.width or 0.4
  local border = ctx_config.border or 'rounded'
  
  -- Get parent window dimensions
  local parent_width = vim.api.nvim_win_get_width(parent_win_id)
  local parent_height = vim.api.nvim_win_get_height(parent_win_id)
  
  -- Calculate content-based height
  local content_height = initial_content_lines and #initial_content_lines or 5
  
  -- Calculate window dimensions and position relative to parent window
  local width, height, row, col
  
  if position == 'bottom' then
    width = math.max(40, math.floor(parent_width * 0.9))  -- 90% of parent width, min 40
    local max_height = math.floor(parent_height * 0.4)  -- Max 40% of parent height
    height = math.min(content_height, max_height)
    height = math.max(height, 1)  -- Minimum 1 line
    row = parent_height - height - 1  -- Bottom of parent window, accounting for status line
    col = math.floor((parent_width - width) / 2)  -- Centered in parent
  elseif position == 'top' then
    width = math.max(40, math.floor(parent_width * 0.9))
    local max_height = math.floor(parent_height * 0.4)
    height = math.min(content_height, max_height)
    height = math.max(height, 1)
    row = 0  -- Top of parent window
    col = math.floor((parent_width - width) / 2)
  elseif position == 'right' then
    width = math.max(30, math.floor(parent_width * width_pct))
    local max_height = parent_height - 4  -- Leave margin
    height = math.min(content_height, max_height)
    height = math.max(height, 1)
    row = math.floor((parent_height - height) / 2)
    col = parent_width - width  -- Right side of parent
  elseif position == 'left' then
    width = math.max(30, math.floor(parent_width * width_pct))
    local max_height = parent_height - 4  -- Leave margin
    height = math.min(content_height, max_height)
    height = math.max(height, 1)
    row = math.floor((parent_height - height) / 2)
    col = 0  -- Left side of parent
  else
    -- Default to bottom
    width = math.max(40, math.floor(parent_width * 0.9))
    local max_height = math.floor(parent_height * 0.4)
    height = math.min(content_height, max_height)
    height = math.max(height, 1)
    row = parent_height - height - 1  -- Account for status line
    col = math.floor((parent_width - width) / 2)
  end
  
  -- Ensure the context window fits within the parent window bounds
  if width > parent_width then
    width = parent_width - 2
    col = 1
  end
  if height > parent_height - 1 then  -- Account for status line
    height = parent_height - 2
    if position == 'bottom' then
      row = 1
    end
  end
  
  -- Adjust position if window would extend beyond parent bounds
  if col + width > parent_width then
    col = parent_width - width
  end
  if col < 0 then
    col = 0
  end
  if row + height > parent_height - 1 then  -- Account for status line
    row = parent_height - height - 1
  end
  if row < 0 then
    row = 0
  end
  
  -- Create buffer
  local buf_id = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_option(buf_id, 'bufhidden', 'wipe')
  vim.api.nvim_buf_set_option(buf_id, 'filetype', 'jj-context')
  vim.api.nvim_buf_set_option(buf_id, 'modifiable', false)
  
  -- Window configuration - use 'win' relative to parent window
  local win_config = {
    relative = 'win',
    win = parent_win_id,
    width = width,
    height = height,
    row = row,
    col = col,
    border = border,
    style = 'minimal',
    focusable = false,
    zindex = 900, -- Lower than action menu (1000)
  }
  
  -- Create window
  local win_id = vim.api.nvim_open_win(buf_id, false, win_config)
  
  -- Set window options
  vim.api.nvim_win_set_option(win_id, 'winhl', 'Normal:Normal,FloatBorder:JJMenuBorder')
  vim.api.nvim_win_set_option(win_id, 'wrap', true)
  
  return buf_id, win_id
end

-- Generate context window content based on selection state
local function generate_context_content(current_commit, selected_commits)
  local lines = {}
  local has_selections = selected_commits and #selected_commits > 0
  local single_selection = has_selections and #selected_commits == 1
  local multi_selection = has_selections and #selected_commits > 1
  
  -- Title based on selection state
  if multi_selection then
    table.insert(lines, string.format("📋 %d commits selected", #selected_commits))
  elseif single_selection then
    -- Find the selected commit to show its info
    local selected_commit = current_commit
    local all_commits = require('jj-nvim.jj.command_utils').get_all_commits()
    if all_commits then
      for _, commit in ipairs(all_commits) do
        local commit_id = commit.change_id or commit.short_change_id
        if commit_id == selected_commits[1] then
          selected_commit = commit
          break
        end
      end
    end
    local command_utils = require('jj-nvim.jj.command_utils')
    local display_id = command_utils.get_short_display_id(selected_commit)
    table.insert(lines, string.format("📋 Selected: %s", display_id))
  elseif current_commit then
    local command_utils = require('jj-nvim.jj.command_utils')
    local display_id = command_utils.get_short_display_id(current_commit)
    table.insert(lines, string.format("📍 Current: %s", display_id))
  else
    table.insert(lines, "❌ No commit available")
  end
  
  table.insert(lines, "")
  
  -- Available actions header
  table.insert(lines, "⚡ Available Actions:")
  
  -- Generate action list (simplified version of action menu logic)
  local target_commit = current_commit
  if single_selection then
    -- Find the selected commit
    local all_commits = require('jj-nvim.jj.command_utils').get_all_commits()
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
  
  -- Common single-commit actions
  if target_commit and not multi_selection then
    table.insert(lines, "  d - Show diff")
    table.insert(lines, "  D - Show diff summary")
    
    -- Only allow certain operations on non-root commits
    if not target_commit.root then
      table.insert(lines, "  e - Edit commit")
      table.insert(lines, "  m - Set description")
      table.insert(lines, "  a - Abandon commit")
      table.insert(lines, "  x - Squash commit")
      table.insert(lines, "  s - Split commit")
      table.insert(lines, "  r - Rebase commit")
    end
    
    table.insert(lines, "  n - New child change")
  end
  
  -- Multi-commit actions
  if multi_selection then
    table.insert(lines, "  a - Abandon selected commits")
    table.insert(lines, "  r - Rebase selected commits")
  end
  
  -- Selection management
  if has_selections then
    table.insert(lines, "  <Esc> - Clear selections")
    table.insert(lines, "  c - Clear selections")
  end
  
  -- Only show global actions when no selections (since some are disabled during selections)
  if not has_selections then
    table.insert(lines, "")
    table.insert(lines, "🔧 Global Actions:")
    table.insert(lines, "  c - Commit working copy")
    table.insert(lines, "  b - Bookmarks")
    table.insert(lines, "  rs - Revset menu")
    table.insert(lines, "  R - Refresh")
  end
  
  -- Always available actions
  table.insert(lines, "")
  table.insert(lines, "🌐 Always Available:")
  table.insert(lines, "  S - Show status")
  table.insert(lines, "  f - Git fetch")
  table.insert(lines, "  p - Git push")
  table.insert(lines, "  u - Undo last operation")
  
  table.insert(lines, "")
  if single_selection then
    table.insert(lines, "💡 Actions will apply to the selected commit")
  elseif multi_selection then
    table.insert(lines, "💡 Actions will apply to all selected commits")
  else
    table.insert(lines, "💡 Actions will apply to the current commit")
  end
  table.insert(lines, string.format("💡 Press %s to open action menu", 
    config.get_first_keybind('keybinds.log_window.actions.action_menu') or '<leader>a'))
  
  return lines
end

-- Update context window content and resize if needed
local function update_context_content(current_commit, selected_commits)
  if not context_state.enabled or not context_state.buf_id or 
     not vim.api.nvim_buf_is_valid(context_state.buf_id) then
    return
  end
  
  local lines = generate_context_content(current_commit, selected_commits)
  
  -- Update buffer content
  vim.api.nvim_buf_set_option(context_state.buf_id, 'modifiable', true)
  vim.api.nvim_buf_set_lines(context_state.buf_id, 0, -1, false, lines)
  vim.api.nvim_buf_set_option(context_state.buf_id, 'modifiable', false)
  
  -- Resize window to fit content
  if context_state.win_id and vim.api.nvim_win_is_valid(context_state.win_id) then
    local content_height = #lines
    local ctx_config = config.get('context_window') or {}
    local position = ctx_config.position or 'bottom'
    local parent_height = vim.api.nvim_win_get_height(context_state.parent_win_id)
    
    -- Calculate max height based on position and parent window
    local max_height
    if position == 'top' or position == 'bottom' then
      max_height = math.floor(parent_height * 0.4)  -- Max 40% of parent height
    else
      max_height = parent_height - 4  -- Leave some margin for left/right positions
    end
    
    -- Use content height but cap at max_height
    local new_height = math.min(content_height, max_height)
    new_height = math.max(new_height, 1)  -- Minimum 1 line
    
    -- Get current window config
    local current_config = vim.api.nvim_win_get_config(context_state.win_id)
    
    -- Update window height (and adjust row position if needed for bottom positioning)
    if position == 'bottom' then
      current_config.row = parent_height - new_height - 1  -- Account for status line
    end
    current_config.height = new_height
    
    vim.api.nvim_win_set_config(context_state.win_id, current_config)
  end
  
  -- Apply syntax highlighting
  local ns_id = vim.api.nvim_create_namespace('jj_context_highlight')
  vim.api.nvim_buf_clear_namespace(context_state.buf_id, ns_id, 0, -1)
  
  for i, line in ipairs(lines) do
    local line_idx = i - 1 -- 0-based indexing
    
    if line:match("^📋") or line:match("^📍") or line:match("^❌") then
      -- Highlight status line
      vim.api.nvim_buf_add_highlight(context_state.buf_id, ns_id, 'JJMenuTitle', line_idx, 0, -1)
    elseif line:match("^⚡") or line:match("^🔧") then
      -- Highlight section headers
      vim.api.nvim_buf_add_highlight(context_state.buf_id, ns_id, 'JJMenuTitle', line_idx, 0, -1)
    elseif line:match("^  %w") then
      -- Highlight key bindings
      local key_end = line:find(" - ")
      if key_end then
        vim.api.nvim_buf_add_highlight(context_state.buf_id, ns_id, 'JJMenuKey', line_idx, 2, key_end - 1)
        vim.api.nvim_buf_add_highlight(context_state.buf_id, ns_id, 'JJMenuDescription', line_idx, key_end, -1)
      end
    elseif line:match("^💡") then
      -- Highlight tip
      vim.api.nvim_buf_add_highlight(context_state.buf_id, ns_id, 'JJMenuDescription', line_idx, 0, -1)
    end
  end
end

-- Show context window
M.show = function(parent_win_id, current_commit, selected_commits)
  if not config.get('context_window.enabled') then
    return
  end
  
  -- Close existing window if any
  M.close()
  
  -- Generate content first to size window appropriately
  local initial_content = generate_context_content(current_commit, selected_commits)
  local buf_id, win_id = create_context_window(parent_win_id, initial_content)
  
  context_state.enabled = true
  context_state.buf_id = buf_id
  context_state.win_id = win_id
  context_state.parent_win_id = parent_win_id
  
  -- Set initial content
  vim.api.nvim_buf_set_option(buf_id, 'modifiable', true)
  vim.api.nvim_buf_set_lines(buf_id, 0, -1, false, initial_content)
  vim.api.nvim_buf_set_option(buf_id, 'modifiable', false)
  
  -- Apply initial syntax highlighting
  local ns_id = vim.api.nvim_create_namespace('jj_context_highlight')
  vim.api.nvim_buf_clear_namespace(buf_id, ns_id, 0, -1)
  
  for i, line in ipairs(initial_content) do
    local line_idx = i - 1 -- 0-based indexing
    
    if line:match("^📋") or line:match("^📍") or line:match("^❌") then
      -- Highlight status line
      vim.api.nvim_buf_add_highlight(buf_id, ns_id, 'JJMenuTitle', line_idx, 0, -1)
    elseif line:match("^⚡") or line:match("^🔧") then
      -- Highlight section headers
      vim.api.nvim_buf_add_highlight(buf_id, ns_id, 'JJMenuTitle', line_idx, 0, -1)
    elseif line:match("^  %w") then
      -- Highlight key bindings
      local key_end = line:find(" - ")
      if key_end then
        vim.api.nvim_buf_add_highlight(buf_id, ns_id, 'JJMenuKey', line_idx, 2, key_end - 1)
        vim.api.nvim_buf_add_highlight(buf_id, ns_id, 'JJMenuDescription', line_idx, key_end, -1)
      end
    elseif line:match("^💡") then
      -- Highlight tip
      vim.api.nvim_buf_add_highlight(buf_id, ns_id, 'JJMenuDescription', line_idx, 0, -1)
    end
  end
  
  -- Auto-close when parent window loses focus
  vim.api.nvim_create_autocmd({"WinLeave", "BufLeave"}, {
    callback = function(ev)
      if ev.buf == vim.api.nvim_win_get_buf(parent_win_id) then
        vim.schedule(function()
          M.close()
        end)
      end
    end,
    once = true,
  })
end

-- Close context window
M.close = function()
  if context_state.win_id and vim.api.nvim_win_is_valid(context_state.win_id) then
    vim.api.nvim_win_close(context_state.win_id, true)
  end
  
  if context_state.buf_id and vim.api.nvim_buf_is_valid(context_state.buf_id) then
    vim.api.nvim_buf_delete(context_state.buf_id, { force = true })
  end
  
  context_state.enabled = false
  context_state.win_id = nil
  context_state.buf_id = nil
  context_state.parent_win_id = nil
end

-- Update context window based on current state
M.update = function(parent_win_id, current_commit, selected_commits)
  local selection_count = selected_commits and #selected_commits or 0
  local auto_show = config.get('context_window.auto_show')
  
  -- Generate context string for comparison
  local context = ""
  if selection_count > 1 then
    context = string.format("multi:%d", selection_count)
  elseif selection_count == 1 then
    context = "single:" .. (selected_commits[1] or "")
  elseif current_commit then
    local command_utils = require('jj-nvim.jj.command_utils')
    local display_id = command_utils.get_short_display_id(current_commit)
    context = "current:" .. display_id
  else
    context = "none"
  end
  
  -- Check if context has changed significantly
  local context_changed = context ~= context_state.last_context
  context_state.last_context = context
  context_state.last_selection_count = selection_count
  
  if auto_show and selection_count > 0 and context_changed then
    -- Show context window when selections are made
    M.show(parent_win_id, current_commit, selected_commits)
  elseif auto_show and selection_count == 0 and context_state.enabled then
    -- Hide context window when no selections
    M.close()
  elseif context_state.enabled then
    -- Update existing context window
    update_context_content(current_commit, selected_commits)
  end
end

-- Check if context window is active
M.is_active = function()
  return context_state.enabled
end

return M