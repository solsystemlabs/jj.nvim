local M = {}

local inline_menu = require('jj-nvim.ui.inline_menu')
local commands = require('jj-nvim.jj.commands')

-- Centralized menu helper to handle timing issues
local function show_menu_with_transition(menu_config, callbacks)
  return inline_menu.show(M.state.parent_win_id, menu_config, {
    on_select = function(item)
      if callbacks.on_select then
        -- Wrap the callback with delay if it leads to another menu
        if callbacks.needs_delay then
          vim.defer_fn(function()
            callbacks.on_select(item)
          end, 100)
        else
          callbacks.on_select(item)
        end
      end
    end,
    on_cancel = function()
      if callbacks.on_cancel then
        -- Wrap cancel callback with delay if needed
        if callbacks.needs_delay then
          vim.defer_fn(function()
            callbacks.on_cancel()
          end, 100)
        else
          callbacks.on_cancel()
        end
      end
    end
  })
end

-- Command flow state
M.state = {
  active = false,
  command = nil,           -- Command being built (e.g., "git_push", "rebase")
  step = 1,                -- Current step (1-5)
  base_options = {},       -- Non-flag options from early steps
  flags = {},              -- Flag state 
  command_preview = "",    -- Live preview of final command
  flow_config = nil,       -- Configuration for this command flow
  parent_win_id = nil,     -- Window to return focus to
}

-- Generate dynamic remote targets for git push
local function generate_git_push_targets()
  local remotes = commands.get_git_remotes()
  local targets = {}
  
  -- Generate targets for each remote
  for i, remote_name in ipairs(remotes) do
    local key = string.sub(remote_name, 1, 1)  -- Use first letter as key
    -- Handle key conflicts by using numbers
    while vim.tbl_contains(vim.tbl_map(function(t) return t.key end, targets), key) do
      key = tostring(i)
    end
    
    table.insert(targets, {
      key = key,
      description = "Push to remote '" .. remote_name .. "'",
      value = { remote = remote_name }
    })
  end
  
  -- Add "all remotes" option if there are multiple remotes
  if #remotes > 1 then
    table.insert(targets, {
      key = "a",
      description = "Push to all remotes",
      value = { remote = "all" }
    })
  end
  
  return targets
end

-- Generate dynamic remote targets for git fetch
local function generate_git_fetch_targets()
  local remotes = commands.get_git_remotes()
  local targets = {}
  
  -- Generate targets for each remote
  for i, remote_name in ipairs(remotes) do
    local key = string.sub(remote_name, 1, 1)  -- Use first letter as key
    -- Handle key conflicts by using numbers
    while vim.tbl_contains(vim.tbl_map(function(t) return t.key end, targets), key) do
      key = tostring(i)
    end
    
    table.insert(targets, {
      key = key,
      description = "Fetch from remote '" .. remote_name .. "'",
      value = { remote = remote_name }
    })
  end
  
  -- Add "all remotes" option if there are multiple remotes
  if #remotes > 1 then
    table.insert(targets, {
      key = "a",
      description = "Fetch from all remotes",
      value = { remote = "all" }
    })
  end
  
  return targets
end

-- Command flow definitions
M.flows = {
  git_push = {
    type = "unified",        -- unified or sequential
    command_base = "jj git push",
    generate_targets = generate_git_push_targets,  -- Dynamic target generation
    steps = {
      {
        type = "unified_menu",
        title = "Git Push",
        targets = nil, -- Will be populated dynamically
        flags = {
          { key = "f", flag = "--force-with-lease", type = "toggle", description = "Force with lease", default = false },
          { key = "n", flag = "--allow-new", type = "toggle", description = "Allow new", default = false },
          { key = "b", flag = "--branch", type = "selection", description = "Specific branch", default = nil, get_options = "get_local_bookmarks" },
        }
      }
    }
  },
  
  git_fetch = {
    type = "unified",        -- unified or sequential
    command_base = "jj git fetch",
    generate_targets = generate_git_fetch_targets,  -- Dynamic target generation
    steps = {
      {
        type = "unified_menu",
        title = "Git Fetch",
        targets = nil, -- Will be populated dynamically
        flags = {
          { key = "b", flag = "--branch", type = "selection", description = "Specific branch", default = nil, get_options = "get_remote_bookmarks" },
        }
      }
    }
  },
  
  rebase = {
    type = "sequential",
    command_base = "jj rebase",
    steps = {
      {
        type = "option_menu", 
        title = "Rebase Source",
        options = {
          { key = "b", description = "Rebase branch (current selection)", value = { source_type = "branch" } },
          { key = "s", description = "Rebase source commits", value = { source_type = "source" } },
          { key = "r", description = "Rebase specific revisions", value = { source_type = "revisions" } },
        }
      },
      {
        type = "selection",
        title = "Choose destination commit/bookmark",
        -- This will be handled by existing selection logic
      },
      {
        type = "flag_menu",
        title = "Rebase Flags", 
        flags = {
          { key = "e", flag = "--skip-emptied", type = "toggle", description = "Skip emptied", default = false },
          { key = "k", flag = "--keep-divergent", type = "toggle", description = "Keep divergent", default = false },
          { key = "i", flag = "--interactive", type = "toggle", description = "Interactive", default = false },
        }
      }
    }
  }
}

-- Build command preview from current state
local function build_command_preview()
  if not M.state.flow_config then
    return ""
  end
  
  local parts = { M.state.flow_config.command_base }
  
  -- Add base options
  for key, value in pairs(M.state.base_options) do
    if key == "remote" and value ~= "all" then
      table.insert(parts, "--remote " .. value)
    elseif key == "remote" and value == "all" then
      if M.state.flow_config.command_base:find("push") then
        table.insert(parts, "--all-remotes")
      else -- git fetch uses different flag
        table.insert(parts, "--all-remotes")
      end
    elseif key == "source_type" and value == "branch" then
      table.insert(parts, "-b")
    elseif key == "source_type" and value == "source" then
      table.insert(parts, "-s")
    elseif key == "source_type" and value == "revisions" then
      table.insert(parts, "-r")
    elseif key == "destination" then
      table.insert(parts, "-d " .. value)
    end
  end
  
  -- Add flags
  if M.state.flags then
    for flag_key, flag_value in pairs(M.state.flags) do
      if flag_value == true then
        -- Find flag definition to get the actual flag name
        local flag_def = M.get_flag_definition(flag_key)
        if flag_def then
          table.insert(parts, flag_def.flag)
        end
      elseif type(flag_value) == "string" and flag_value ~= "" then
        local flag_def = M.get_flag_definition(flag_key)
        if flag_def then
          table.insert(parts, flag_def.flag .. " " .. flag_value)
        end
      end
    end
  end
  
  return table.concat(parts, " ")
end

-- Get flag definition by key from current flow
M.get_flag_definition = function(flag_key)
  if not M.state.flow_config then
    return nil
  end
  
  for _, step in ipairs(M.state.flow_config.steps) do
    if step.flags then
      for _, flag_def in ipairs(step.flags) do
        if flag_def.key == flag_key then
          return flag_def
        end
      end
    end
  end
  
  return nil
end

-- Start a command flow
M.start_flow = function(command_name, parent_win_id)
  -- Close any existing flow
  if M.state.active then
    M.close()
  end
  
  local flow_config = M.flows[command_name]
  if not flow_config then
    vim.notify("Unknown command flow: " .. command_name, vim.log.levels.ERROR)
    return false
  end
  
  -- Generate dynamic targets if function is provided
  if flow_config.generate_targets then
    local dynamic_targets = flow_config.generate_targets()
    -- Update the first step with generated targets
    flow_config.steps[1].targets = dynamic_targets
  end
  
  -- Initialize state
  M.state.active = true
  M.state.command = command_name
  M.state.step = 1
  M.state.base_options = {}
  M.state.flags = {}
  M.state.flow_config = flow_config
  M.state.parent_win_id = parent_win_id
  
  -- Initialize flags with defaults
  for _, step in ipairs(flow_config.steps) do
    if step.flags then
      for _, flag_def in ipairs(step.flags) do
        M.state.flags[flag_def.key] = flag_def.default
      end
    end
  end
  
  -- Start first step
  M.show_current_step()
  
  return true
end

-- Show the current step's menu
M.show_current_step = function()
  if not M.state.active or not M.state.flow_config then
    vim.notify("Flow not active or no config", vim.log.levels.ERROR)
    return false
  end
  
  -- Close any existing menu first (but add a small delay to prevent rapid recreation)
  if inline_menu.is_active() then
    inline_menu.close()
    -- Small delay to ensure the previous menu is fully closed
    vim.defer_fn(function() end, 50)
  end
  
  local step_config = M.state.flow_config.steps[M.state.step]
  if not step_config then
    vim.notify("Invalid step: " .. M.state.step, vim.log.levels.ERROR)
    return false
  end
  
  -- Update command preview
  M.state.command_preview = build_command_preview()
  
  if step_config.type == "unified_menu" then
    M.show_unified_menu(step_config)
  elseif step_config.type == "option_menu" then
    M.show_option_menu(step_config)
  elseif step_config.type == "flag_menu" then
    M.show_flag_menu(step_config)
  elseif step_config.type == "selection" then
    M.show_selection_step(step_config)
  else
    vim.notify("Unknown step type: " .. step_config.type, vim.log.levels.ERROR)
    return false
  end
  
  return true
end

-- Show unified menu (targets + flags in one menu)
M.show_unified_menu = function(step_config)
  local menu_items = {}
  
  -- Add target options
  if step_config.targets then
    for _, target in ipairs(step_config.targets) do
      table.insert(menu_items, {
        key = target.key,
        description = target.description,
        action = "select_target",
        data = target.value
      })
    end
    
    -- Add visual separator (skip in final items list since inline_menu doesn't support separators)
  end
  
  -- Add flag toggles
  if step_config.flags then
    for _, flag_def in ipairs(step_config.flags) do
      local flag_value = M.state.flags and M.state.flags[flag_def.key]
      local indicator
      if flag_def.type == "toggle" then
        indicator = flag_value and "✓" or "✗"
      elseif flag_def.type == "input" then
        indicator = (flag_value and flag_value ~= "") and (":" .. flag_value) or ": <none>"
      elseif flag_def.type == "selection" then
        indicator = (flag_value and flag_value ~= "") and (":" .. flag_value) or ": <none>"
      else
        indicator = flag_value and tostring(flag_value) or "✗"
      end
      
      table.insert(menu_items, {
        key = flag_def.key,
        description = flag_def.description .. ": " .. indicator,
        action = "toggle_flag",
        data = flag_def
      })
    end
    
    -- Add visual separator (skip in final items list since inline_menu doesn't support separators)
  end
  
  -- Add execution option
  table.insert(menu_items, {
    key = "<CR>",
    description = "Execute command",
    action = "execute"
  })
  
  local menu_config = {
    title = step_config.title .. "    [Current: " .. M.state.command_preview .. "]",
    items = menu_items
  }
  
  show_menu_with_transition(menu_config, {
    on_select = M.handle_menu_selection,
    on_cancel = M.close,
    needs_delay = false  -- Unified menus handle their own transitions in M.handle_menu_selection
  })
end

-- Show option menu (non-flag options)
M.show_option_menu = function(step_config)
  local menu_items = {}
  
  for _, option in ipairs(step_config.options) do
    table.insert(menu_items, {
      key = option.key,
      description = option.description,
      action = "select_option", 
      data = option.value
    })
  end
  
  local menu_config = {
    title = step_config.title,
    items = menu_items
  }
  
  show_menu_with_transition(menu_config, {
    on_select = M.handle_menu_selection,
    on_cancel = M.close,
    needs_delay = true  -- Option menus lead to other menus
  })
end

-- Show flag menu
M.show_flag_menu = function(step_config)
  local menu_items = {}
  
  for _, flag_def in ipairs(step_config.flags) do
    local flag_value = M.state.flags[flag_def.key]
    local indicator
    if flag_def.type == "toggle" then
      indicator = flag_value and "✓" or "✗"
    elseif flag_def.type == "input" then
      indicator = flag_value and (":" .. flag_value) or ": <none>"
    else
      indicator = flag_value and tostring(flag_value) or "✗"
    end
    
    table.insert(menu_items, {
      key = flag_def.key,
      description = flag_def.description .. ": " .. indicator,
      action = "toggle_flag",
      data = flag_def
    })
  end
  
  -- Add execution option
  table.insert(menu_items, {
    key = "<CR>",
    description = "Execute command",
    action = "execute"
  })
  
  local menu_config = {
    title = step_config.title .. "    [Current: " .. M.state.command_preview .. "]",
    items = menu_items
  }
  
  show_menu_with_transition(menu_config, {
    on_select = M.handle_menu_selection,
    on_cancel = M.close,
    needs_delay = false  -- Flag menus handle their own transitions in M.handle_menu_selection
  })
end

-- Show selection step - choose target commit/bookmark
M.show_selection_step = function(step_config)
  local bookmark_commands = require('jj-nvim.jj.bookmark_commands')
  local options = {}
  
  -- Get all present bookmarks as destination options
  local bookmarks = bookmark_commands.get_all_present_bookmarks()
  for i, bookmark in ipairs(bookmarks) do
    local key = string.sub(tostring(i), 1, 1)  -- Use number as key
    if i > 9 then key = string.char(96 + i - 9) end  -- a, b, c... for items 10+
    
    table.insert(options, {
      key = key,
      description = bookmark.display_name or bookmark.name,
      value = { destination = bookmark.name }
    })
  end
  
  -- TODO: Could also add recent commits here as options
  
  if #options == 0 then
    vim.notify("No bookmark destinations found", vim.log.levels.WARN)
    return
  end
  
  local menu_config = {
    title = step_config.title,
    items = options
  }
  
  show_menu_with_transition(menu_config, {
    on_select = function(item)
      -- Store the destination selection
      for key, value in pairs(item.value) do
        M.state.base_options[key] = value
      end
      M.advance_step()
    end,
    on_cancel = M.close,
    needs_delay = true  -- Selection leads to flag menu
  })
end

-- Handle menu selection
M.handle_menu_selection = function(item)
  if item.action == "select_target" then
    -- Store target selection in base_options
    for key, value in pairs(item.data) do
      M.state.base_options[key] = value
    end
    
    -- For unified menus, stay on same step but re-render to update preview
    if M.state.flow_config.type == "unified" then
      vim.schedule(function()
        M.show_current_step()
      end)
    else
      M.advance_step()
    end
    
  elseif item.action == "select_option" then
    -- Store option selection in base_options  
    for key, value in pairs(item.data) do
      M.state.base_options[key] = value
    end
    M.advance_step()
    
  elseif item.action == "toggle_flag" then
    local flag_def = item.data
    if flag_def.type == "toggle" then
      M.state.flags[flag_def.key] = not M.state.flags[flag_def.key]
      -- Re-render current step to show updated flag states
      -- The menu will close (due to selection) and we'll reopen it with updated state
      vim.defer_fn(function()
        M.show_current_step()
      end, 100) -- Longer delay to ensure menu is fully closed
    elseif flag_def.type == "input" then
      M.prompt_flag_input(flag_def)
      return -- Don't re-render yet, wait for input
    elseif flag_def.type == "selection" then
      -- The menu will close (due to selection) and we'll show selection menu after delay
      vim.defer_fn(function()
        M.show_flag_selection(flag_def)
      end, 100)
      return -- Don't re-render yet, wait for selection
    end
    
  elseif item.action == "execute" then
    M.execute_command()
  end
end

-- Prompt for flag input
M.prompt_flag_input = function(flag_def)
  local current_value = M.state.flags[flag_def.key] or ""
  vim.ui.input({
    prompt = flag_def.description .. ": ",
    default = current_value
  }, function(input)
    if input ~= nil then  -- User didn't cancel
      M.state.flags[flag_def.key] = input
    end
    -- Re-render current step
    M.show_current_step()
  end)
end

-- Show selection menu for flag options
M.show_flag_selection = function(flag_def)
  local bookmark_commands = require('jj-nvim.jj.bookmark_commands')
  local options = {}
  
  -- Get bookmark options based on the get_options function
  if flag_def.get_options == "get_local_bookmarks" then
    local bookmarks = bookmark_commands.get_local_bookmarks()
    for i, bookmark in ipairs(bookmarks) do
      local key = string.sub(tostring(i), 1, 1)  -- Use number as key
      if i > 9 then key = string.char(96 + i - 9) end  -- a, b, c... for items 10+
      
      table.insert(options, {
        key = key,
        description = bookmark.name,
        value = bookmark.name
      })
    end
  elseif flag_def.get_options == "get_remote_bookmarks" then
    local bookmarks = bookmark_commands.get_remote_bookmarks()
    for i, bookmark in ipairs(bookmarks) do
      local key = string.sub(tostring(i), 1, 1)  -- Use number as key
      if i > 9 then key = string.char(96 + i - 9) end  -- a, b, c... for items 10+
      
      table.insert(options, {
        key = key,
        description = bookmark.display_name or bookmark.name,
        value = bookmark.name
      })
    end
  end
  
  -- Add "none" option
  table.insert(options, 1, {
    key = "n",
    description = "None (clear selection)",
    value = nil
  })
  
  if #options <= 1 then  -- Only "none" option
    vim.notify("No " .. (flag_def.get_options == "get_local_bookmarks" and "local bookmarks" or "remote bookmarks") .. " found", vim.log.levels.WARN)
    return
  end
  
  local menu_config = {
    title = "Select " .. flag_def.description,
    items = options
  }
  
  show_menu_with_transition(menu_config, {
    on_select = function(item)
      M.state.flags[flag_def.key] = item.value
      M.show_current_step()
    end,
    on_cancel = function()
      M.show_current_step()
    end,
    needs_delay = true  -- Flag selection leads back to main menu
  })
end

-- Advance to next step
M.advance_step = function()
  M.state.step = M.state.step + 1
  
  if M.state.step > #M.state.flow_config.steps then
    -- No more steps, execute command
    M.execute_command()
  else
    M.show_current_step()
  end
end

-- Execute the final command
M.execute_command = function()
  local final_command = build_command_preview()
  
  -- Store command state before closing the flow
  local command_type = M.state.command
  local base_options = vim.deepcopy(M.state.base_options)
  local flags = vim.deepcopy(M.state.flags)
  
  -- Close the flow
  M.close()
  
  -- Build command args for execution
  local cmd_args = {}
  
  if command_type == "git_push" then
    table.insert(cmd_args, "git")
    table.insert(cmd_args, "push")
    
    -- Add remote
    local remote = base_options.remote
    if remote == "all" then
      table.insert(cmd_args, "--all-remotes")
    elseif remote then
      table.insert(cmd_args, "--remote")
      table.insert(cmd_args, remote)
    end
    
    -- Add flags
    if flags.f then  -- force-with-lease
      table.insert(cmd_args, "--force-with-lease")
    end
    if flags.n then  -- allow-new
      table.insert(cmd_args, "--allow-new")
    end
    if flags.b and flags.b ~= "" then  -- specific branch
      table.insert(cmd_args, "--branch")
      table.insert(cmd_args, flags.b)
    end
    
    -- Execute the command
    vim.notify("Executing: " .. final_command, vim.log.levels.INFO)
    commands.execute_async(cmd_args, {}, function(result, error_msg)
      if result then
        vim.notify("Git push completed successfully", vim.log.levels.INFO)
        -- Refresh the jj log
        vim.schedule(function()
          require('jj-nvim').refresh()
        end)
      else
        vim.notify("Git push failed: " .. (error_msg or "Unknown error"), vim.log.levels.ERROR)
      end
    end)
  elseif command_type == "git_fetch" then
    table.insert(cmd_args, "git")
    table.insert(cmd_args, "fetch")
    
    -- Add remote
    local remote = base_options.remote
    if remote == "all" then
      table.insert(cmd_args, "--all-remotes")
    elseif remote then
      table.insert(cmd_args, "--remote")
      table.insert(cmd_args, remote)
    end
    
    -- Add flags
    if flags.b and flags.b ~= "" then  -- specific branch
      table.insert(cmd_args, "--branch")
      table.insert(cmd_args, flags.b)
    end
    
    -- Execute the command
    vim.notify("Executing: " .. final_command, vim.log.levels.INFO)
    commands.execute_async(cmd_args, {}, function(result, error_msg)
      if result then
        vim.notify("Git fetch completed successfully", vim.log.levels.INFO)
        -- Refresh the jj log
        vim.schedule(function()
          require('jj-nvim').refresh()
        end)
      else
        vim.notify("Git fetch failed: " .. (error_msg or "Unknown error"), vim.log.levels.ERROR)
      end
    end)
  elseif command_type == "rebase" then
    table.insert(cmd_args, "rebase")
    
    -- Add source type and revset
    local source_type = base_options.source_type
    if source_type == "branch" then
      table.insert(cmd_args, "-b")
      table.insert(cmd_args, "@")  -- Rebase current commit/branch
    elseif source_type == "source" then
      table.insert(cmd_args, "-s")
      table.insert(cmd_args, "@")  -- Rebase current commit as source
    elseif source_type == "revisions" then
      table.insert(cmd_args, "-r")
      table.insert(cmd_args, "@")  -- Rebase current commit as revision
    end
    
    -- Add destination
    if base_options.destination then
      table.insert(cmd_args, "-d")
      table.insert(cmd_args, base_options.destination)
    end
    
    -- Add flags
    if flags.skip_emptied then
      table.insert(cmd_args, "--skip-emptied")
    end
    if flags.keep_divergent then
      table.insert(cmd_args, "--keep-divergent")
    end
    if flags.interactive then
      table.insert(cmd_args, "--interactive")
    end
    
    -- Execute the command
    vim.notify("Executing: " .. final_command, vim.log.levels.INFO)
    commands.execute_async(cmd_args, {}, function(result, error_msg)
      if result then
        vim.notify("Rebase completed successfully", vim.log.levels.INFO)
        -- Refresh the jj log
        vim.schedule(function()
          require('jj-nvim').refresh()
        end)
      else
        vim.notify("Rebase failed: " .. (error_msg or "Unknown error"), vim.log.levels.ERROR)
      end
    end)
  else
    -- Fallback for other commands not yet implemented
    vim.notify("Command not yet implemented: " .. final_command, vim.log.levels.WARN)
  end
end

-- Close the command flow
M.close = function()
  if not M.state.active then
    return
  end
  
  -- Close any active menu
  if inline_menu.is_active() then
    inline_menu.close()
  end
  
  -- Reset state
  M.state = {
    active = false,
    command = nil,
    step = 1,
    base_options = {},
    flags = {},
    command_preview = "",
    flow_config = nil,
    parent_win_id = nil,
  }
end

-- Check if flow is active
M.is_active = function()
  return M.state.active
end

-- Get current state (for debugging)
M.get_state = function()
  return vim.deepcopy(M.state)
end

return M