local M = {}

local inline_menu = require('jj-nvim.ui.inline_menu')
local commands = require('jj-nvim.jj.commands')

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
          { key = "b", flag = "--branch", type = "input", description = "Specific branch", default = nil },
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
          { key = "b", flag = "--branch", type = "input", description = "Specific branch", default = nil },
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
  
  inline_menu.show(M.state.parent_win_id, menu_config, {
    on_select = M.handle_menu_selection,
    on_cancel = M.close
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
  
  inline_menu.show(M.state.parent_win_id, menu_config, {
    on_select = M.handle_menu_selection,
    on_cancel = M.close
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
  
  inline_menu.show(M.state.parent_win_id, menu_config, {
    on_select = M.handle_menu_selection,
    on_cancel = M.close
  })
end

-- Show selection step (placeholder - will integrate with existing selection logic)
M.show_selection_step = function(step_config)
  vim.notify("Selection step not yet implemented", vim.log.levels.INFO)
  -- For now, just advance to next step
  M.advance_step()
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
    vim.notify("Flag type: " .. tostring(flag_def.type) .. " for key: " .. tostring(flag_def.key), vim.log.levels.INFO)
    if flag_def.type == "toggle" then
      M.state.flags[flag_def.key] = not M.state.flags[flag_def.key]
      -- Re-render current step to show updated flag states
      -- The menu will close (due to selection) and we'll reopen it with updated state
      vim.defer_fn(function()
        M.show_current_step()
      end, 100) -- Longer delay to ensure menu is fully closed
    elseif flag_def.type == "input" then
      vim.notify("Calling prompt_flag_input...", vim.log.levels.INFO)
      M.prompt_flag_input(flag_def)
      return -- Don't re-render yet, wait for input
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