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
  command = nil,        -- Command being built (e.g., "git_push", "rebase")
  step = 1,             -- Current step (1-5)
  base_options = {},    -- Non-flag options from early steps
  flags = {},           -- Flag state
  command_preview = "", -- Live preview of final command
  flow_config = nil,    -- Configuration for this command flow
  parent_win_id = nil,  -- Window to return focus to
  cursor_commit = nil,  -- Commit that was under cursor when flow started
}

-- Generate dynamic remote targets for git commands
local function generate_git_remote_targets(operation)
  local remotes = commands.get_git_remotes()
  local targets = {}

  -- Generate targets for each remote
  for i, remote_name in ipairs(remotes) do
    local key = string.sub(remote_name, 1, 1) -- Use first letter as key
    -- Handle key conflicts by using numbers
    while vim.tbl_contains(vim.tbl_map(function(t) return t.key end, targets), key) do
      key = tostring(i)
    end

    table.insert(targets, {
      key = key,
      description = operation .. " to remote '" .. remote_name .. "'",
      value = { remote = remote_name }
    })
  end

  -- Add "all remotes" option if there are multiple remotes
  if #remotes > 1 then
    table.insert(targets, {
      key = "a",
      description = operation .. " to all remotes",
      value = { remote = "all" }
    })
  end

  return targets
end

-- Generate git push targets
local function generate_git_push_targets()
  return generate_git_remote_targets("Push")
end

-- Generate git fetch targets
local function generate_git_fetch_targets()
  return generate_git_remote_targets("Fetch from")
end

-- Common success/failure callback helper
local function create_async_callback(operation_name)
  return function(result, error_msg)
    if result then
      vim.notify(operation_name .. " completed successfully", vim.log.levels.INFO)
      vim.schedule(function()
        require('jj-nvim').refresh()
      end)
    else
      vim.notify(operation_name .. " failed: " .. (error_msg or "Unknown error"), vim.log.levels.ERROR)
    end
  end
end

local function create_interactive_callbacks(operation_name)
  return {
    on_success = function()
      vim.notify("Interactive " .. operation_name .. " completed successfully", vim.log.levels.INFO)
      vim.schedule(function()
        require('jj-nvim').refresh()
      end)
    end,
    on_error = function(exit_code)
      vim.notify("Interactive " .. operation_name .. " failed", vim.log.levels.ERROR)
    end,
    on_cancel = function()
      vim.notify("Interactive " .. operation_name .. " cancelled", vim.log.levels.INFO)
    end
  }
end

-- Common git remote handling
local function add_git_remote_args(cmd_args, remote)
  if remote == "all" then
    table.insert(cmd_args, "--all-remotes")
  elseif remote then
    table.insert(cmd_args, "--remote")
    table.insert(cmd_args, remote)
  end
end

-- Command flow definitions
M.flows = {
  git_push = {
    type = "unified",                             -- unified or sequential
    command_base = "jj git push",
    generate_targets = generate_git_push_targets, -- Dynamic target generation
    steps = {
      {
        type = "unified_menu",
        title = "Git Push",
        targets = nil, -- Will be populated dynamically
        flags = {
          { key = "f", flag = "--force-with-lease", type = "toggle",    description = "Force with lease", default = false },
          { key = "n", flag = "--allow-new",        type = "toggle",    description = "Allow new",        default = false },
          { key = "b", flag = "--branch",           type = "selection", description = "Specific branch",  default = nil,  get_options = "get_local_bookmarks" },
        }
      }
    }
  },

  git_fetch = {
    type = "unified",                              -- unified or sequential
    command_base = "jj git fetch",
    generate_targets = generate_git_fetch_targets, -- Dynamic target generation
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
        title = "Rebase Target",
        options = {
          { key = "t", description = "Choose target (commit/bookmark)", value = { target_selection_type = "choose" } },
          { key = "b", description = "Rebase onto bookmark",             value = { target_selection_type = "bookmark" } },
        }
      },
      {
        type = "target_selection",
        title = "Choose destination commit/bookmark",
        condition = function(state)
          return state.base_options.target_selection_type == "choose"
        end
      },
      {
        type = "selection",
        title = "Choose bookmark destination",
        condition = function(state)
          return state.base_options.target_selection_type == "bookmark"
        end
      },
      {
        type = "flag_menu",
        title = "Rebase Flags",
        flags = {
          { key = "e", flag = "--skip-emptied",   type = "toggle", description = "Skip emptied",   default = false },
          { key = "k", flag = "--keep-divergent", type = "toggle", description = "Keep divergent", default = false },
          { key = "i", flag = "--interactive",    type = "toggle", description = "Interactive",    default = false },
        }
      }
    }
  },

  duplicate = {
    type = "sequential",
    command_base = "jj duplicate",
    steps = {
      {
        type = "option_menu",
        title = "Duplicate Source",
        options = {
          { key = "c", description = "Duplicate current commit", value = { source_type = "current" } },
          { key = "m", description = "Select multiple commits", value = { source_type = "multiple" } },
        }
      },
      {
        type = "option_menu",
        title = "Duplicate Options",
        options = {
          { key = "q", description = "Quick duplicate (in place)", value = { target_type = "none" } },
          { key = "d", description = "Duplicate to destination", value = { target_type = "destination" } },
          { key = "a", description = "Duplicate after target", value = { target_type = "insert_after" } },
          { key = "b", description = "Duplicate before target", value = { target_type = "insert_before" } },
        }
      },
      {
        type = "target_selection",
        title = "Choose target commit/bookmark",
        condition = function(state)
          return state.base_options.target_type ~= "none"
        end
      }
    }
  },

  squash = {
    type = "sequential",
    command_base = "jj squash",
    steps = {
      {
        type = "option_menu",
        title = "Squash Target",
        options = {
          { key = "p", description = "Into parent",   value = { target_type = "parent" } },
          { key = "i", description = "Choose target", value = { target_type = "target_selection" } },
        }
      },
      {
        type = "target_selection",
        title = "Choose destination",
        -- Uses window target selection mode with log/bookmark toggle
      },
      {
        type = "flag_menu",
        title = "Squash Flags",
        flags = {
          { key = "k", flag = "--keep-emptied",            type = "toggle", description = "Keep emptied",     default = false },
          { key = "m", flag = "--use-destination-message", type = "toggle", description = "Use dest message", default = false },
          { key = "i", flag = "--interactive",             type = "toggle", description = "Interactive",      default = false },
        }
      }
    }
  },

  split = {
    type = "sequential",
    command_base = "jj split",
    steps = {
      {
        type = "option_menu",
        title = "Split Method",
        options = {
          { key = "i", description = "Interactive",        value = { split_method = "interactive" } },
          { key = "p", description = "Parallel",           value = { split_method = "parallel" } },
          { key = "a", description = "Insert after",       value = { split_method = "insert_after" } },
          { key = "b", description = "Insert before",      value = { split_method = "insert_before" } },
          { key = "d", description = "Choose destination", value = { split_method = "destination" } },
        }
      },
      {
        type = "target_selection",
        title = "Choose target",
        -- Only shown for insert_after, insert_before, destination methods
      },
      {
        type = "flag_menu",
        title = "Split Flags",
        flags = {
          { key = "m", flag = "-m",     type = "input", description = "Message", default = "" },
          { key = "t", flag = "--tool", type = "input", description = "Tool",    default = "" },
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
    elseif key == "target_type" and value == "parent" then
      -- For squash into parent, show the target
      if M.state.flow_config.command_base:find("squash") then
        local source_commit = M.state.cursor_commit or "@"
        table.insert(parts, "--from " .. source_commit .. " --into " .. source_commit .. "-")
      end
    elseif key == "target_type" and value == "target_selection" and M.state.base_options.destination then
      -- For squash into target selection, show the destination
      if M.state.flow_config.command_base:find("squash") then
        local source_commit = M.state.cursor_commit or "@"
        table.insert(parts, "--from " .. source_commit .. " --into " .. M.state.base_options.destination)
      end
    elseif key == "split_method" then
      -- For split methods, show the appropriate flags
      if M.state.flow_config.command_base:find("split") then
        local source_commit = M.state.cursor_commit or "@"
        table.insert(parts, "-r " .. source_commit)
        if value == "parallel" then
          table.insert(parts, "--parallel")
        elseif value == "insert_after" and M.state.base_options.destination then
          table.insert(parts, "-A " .. M.state.base_options.destination)
        elseif value == "insert_before" and M.state.base_options.destination then
          table.insert(parts, "-B " .. M.state.base_options.destination)
        elseif value == "destination" and M.state.base_options.destination then
          table.insert(parts, "-d " .. M.state.base_options.destination)
        end
        -- Always add interactive for splits (consistent with execution)
        table.insert(parts, "--interactive")
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

  -- Capture the commit under cursor when flow starts
  local navigation = require('jj-nvim.ui.navigation')
  local cursor_commit = navigation.get_current_commit(parent_win_id)
  local cursor_commit_id = nil
  if cursor_commit then
    cursor_commit_id = cursor_commit.change_id or cursor_commit.commit_id
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
  M.state.cursor_commit = cursor_commit_id

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
  elseif step_config.type == "target_selection" then
    M.show_target_selection_step(step_config)
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
    needs_delay = false -- Unified menus handle their own transitions in M.handle_menu_selection
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
    needs_delay = true -- Option menus lead to other menus
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
    needs_delay = false -- Flag menus handle their own transitions in M.handle_menu_selection
  })
end

-- Show selection step - choose target commit/bookmark
M.show_selection_step = function(step_config)
  local bookmark_commands = require('jj-nvim.jj.bookmark_commands')
  local options = {}

  -- Get all present bookmarks as destination options
  local bookmarks = bookmark_commands.get_all_present_bookmarks()
  for i, bookmark in ipairs(bookmarks) do
    local key = string.sub(tostring(i), 1, 1)       -- Use number as key
    if i > 9 then key = string.char(96 + i - 9) end -- a, b, c... for items 10+

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
    needs_delay = true -- Selection leads to flag menu
  })
end

-- Show target selection step - uses window target selection mode
M.show_target_selection_step = function(step_config)
  local window_module = require('jj-nvim.ui.window')

  -- Store command flow state for resumption
  local flow_state = vim.deepcopy(M.state)

  -- Close the current flow
  M.close()

  -- Use generic target selection mode with custom callbacks
  local source_data = {
    callbacks = {
      on_confirm = function(target, target_type)
        -- Restore command flow state
        M.state = flow_state
        M.state.active = true

        -- Store the selected target
        if target_type == "commit" then
          local command_utils = require('jj-nvim.jj.command_utils')
          local target_id, err = command_utils.get_change_id(target)
          if target_id then
            M.state.base_options.destination = target_id
          else
            vim.notify("Failed to get target commit ID: " .. (err or "Unknown error"), vim.log.levels.ERROR)
            return
          end
        elseif target_type == "bookmark" then
          M.state.base_options.destination = target.name
        end

        -- Advance to next step
        M.advance_step()
      end,
      on_cancel = function()
        vim.notify(string.format("%s cancelled", flow_state.command:gsub("^%l", string.upper)), vim.log.levels.INFO)
      end
    }
  }

  -- Enter target selection mode with the generic handler
  window_module.enter_target_selection_mode("generic", "destination", source_data)
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
    if input ~= nil then -- User didn't cancel
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
      local key = string.sub(tostring(i), 1, 1)       -- Use number as key
      if i > 9 then key = string.char(96 + i - 9) end -- a, b, c... for items 10+

      table.insert(options, {
        key = key,
        description = bookmark.name,
        value = bookmark.name
      })
    end
  elseif flag_def.get_options == "get_remote_bookmarks" then
    local bookmarks = bookmark_commands.get_remote_bookmarks()
    for i, bookmark in ipairs(bookmarks) do
      local key = string.sub(tostring(i), 1, 1)       -- Use number as key
      if i > 9 then key = string.char(96 + i - 9) end -- a, b, c... for items 10+

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

  if #options <= 1 then -- Only "none" option
    vim.notify(
      "No " .. (flag_def.get_options == "get_local_bookmarks" and "local bookmarks" or "remote bookmarks") .. " found",
      vim.log.levels.WARN)
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
    needs_delay = true -- Flag selection leads back to main menu
  })
end

-- Advance to next step
M.advance_step = function()
  M.state.step = M.state.step + 1

  -- Skip target selection step for squash if target is parent
  if M.state.command == "squash" and M.state.step == 2 and M.state.base_options.target_type == "parent" then
    M.state.step = M.state.step + 1 -- Skip target selection step, go to flags
  end

  -- Skip target selection step for split if method doesn't need target
  if M.state.command == "split" and M.state.step == 2 then
    local split_method = M.state.base_options.split_method
    if split_method == "interactive" or split_method == "parallel" then
      M.state.step = M.state.step + 1 -- Skip target selection step, go to flags
    end
  end
  
  -- Handle duplicate multi-select: if user selected multiple commits, enter multi-select mode
  if M.state.command == "duplicate" and M.state.step == 2 and M.state.base_options.source_type == "multiple" then
    local window_module = require('jj-nvim.ui.window')
    window_module.enter_duplicate_multi_select_mode()
    return -- Don't advance to next step, wait for multi-select completion
  end

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
  local selected_commits = M.state.selected_commits and vim.deepcopy(M.state.selected_commits) or nil
  local cursor_commit = M.state.cursor_commit

  -- Close the flow
  M.close()

  -- Build command args for execution
  local cmd_args = {}

  if command_type == "git_push" then
    table.insert(cmd_args, "git")
    table.insert(cmd_args, "push")

    -- Add remote
    add_git_remote_args(cmd_args, base_options.remote)

    -- Add flags
    if flags.f then -- force-with-lease
      table.insert(cmd_args, "--force-with-lease")
    end
    if flags.n then -- allow-new
      table.insert(cmd_args, "--allow-new")
    end
    if flags.b and flags.b ~= "" then -- specific branch
      table.insert(cmd_args, "--branch")
      table.insert(cmd_args, flags.b)
    end

    -- Execute the command
    vim.notify("Executing: " .. final_command, vim.log.levels.INFO)
    commands.execute_async(cmd_args, {}, create_async_callback("Git push"))
  elseif command_type == "git_fetch" then
    table.insert(cmd_args, "git")
    table.insert(cmd_args, "fetch")

    -- Add remote
    add_git_remote_args(cmd_args, base_options.remote)

    -- Add flags
    if flags.b and flags.b ~= "" then -- specific branch
      table.insert(cmd_args, "--branch")
      table.insert(cmd_args, flags.b)
    end

    -- Execute the command
    vim.notify("Executing: " .. final_command, vim.log.levels.INFO)
    commands.execute_async(cmd_args, {}, create_async_callback("Git fetch"))
  elseif command_type == "rebase" then
    table.insert(cmd_args, "rebase")

    -- Add source type and revset
    local source_type = base_options.source_type
    local source_commit = cursor_commit or "@"
    if source_type == "branch" then
      table.insert(cmd_args, "-b")
      table.insert(cmd_args, source_commit) -- Rebase cursor commit/branch
    elseif source_type == "source" then
      table.insert(cmd_args, "-s")
      table.insert(cmd_args, source_commit) -- Rebase cursor commit as source
    elseif source_type == "revisions" then
      table.insert(cmd_args, "-r")
      table.insert(cmd_args, source_commit) -- Rebase cursor commit as revision
    end

    -- Add destination
    if base_options.destination then
      table.insert(cmd_args, "-d")
      table.insert(cmd_args, base_options.destination)
    end

    -- Add flags
    if flags.e then -- skip-emptied (using key from flag definition)
      table.insert(cmd_args, "--skip-emptied")
    end
    if flags.k then -- keep-divergent
      table.insert(cmd_args, "--keep-divergent")
    end
    if flags.i then -- interactive
      table.insert(cmd_args, "--interactive")
    end

    -- Execute the command
    vim.notify("Executing: " .. final_command, vim.log.levels.INFO)

    -- Use interactive execution if interactive flag is set
    if flags.i then
      local success = commands.execute_interactive_with_immutable_prompt(cmd_args, create_interactive_callbacks("rebase"))
      if not success then
        vim.notify("Failed to start interactive rebase", vim.log.levels.ERROR)
      end
    else
      commands.execute_async(cmd_args, {}, create_async_callback("Rebase"))
    end
  elseif command_type == "squash" then
    table.insert(cmd_args, "squash")

    -- Add source (cursor commit)
    table.insert(cmd_args, "--from")
    local source_commit = cursor_commit or "@"
    table.insert(cmd_args, source_commit)

    -- Add destination based on target type
    local target_type = base_options.target_type
    if target_type == "parent" then
      table.insert(cmd_args, "--into")
      table.insert(cmd_args, source_commit .. "-") -- Parent of cursor commit
    elseif target_type == "target_selection" and base_options.destination then
      table.insert(cmd_args, "--into")
      table.insert(cmd_args, base_options.destination)
    else
      vim.notify("Invalid squash target configuration", vim.log.levels.ERROR)
      return
    end

    -- Add flags
    if flags.k then -- keep-emptied (using key from flag definition)
      table.insert(cmd_args, "--keep-emptied")
    end
    if flags.m then -- use-destination-message
      table.insert(cmd_args, "--use-destination-message")
    end
    if flags.i then -- interactive
      table.insert(cmd_args, "--interactive")
    end

    -- Execute the command
    vim.notify("Executing: " .. final_command, vim.log.levels.INFO)

    -- Use interactive execution if interactive flag is set
    if flags.i then
      local success = commands.execute_interactive_with_immutable_prompt(cmd_args, create_interactive_callbacks("squash"))
      if not success then
        vim.notify("Failed to start interactive squash", vim.log.levels.ERROR)
      end
    else
      commands.execute_async(cmd_args, {}, create_async_callback("Squash"))
    end
  elseif command_type == "split" then
    table.insert(cmd_args, "split")

    -- Add revision (cursor commit)
    table.insert(cmd_args, "-r")
    local source_commit = cursor_commit or "@"
    table.insert(cmd_args, source_commit)

    -- Add split method specific options
    local split_method = base_options.split_method
    if split_method == "parallel" then
      table.insert(cmd_args, "--parallel")
    elseif split_method == "insert_after" and base_options.destination then
      table.insert(cmd_args, "-A")
      table.insert(cmd_args, base_options.destination)
    elseif split_method == "insert_before" and base_options.destination then
      table.insert(cmd_args, "-B")
      table.insert(cmd_args, base_options.destination)
    elseif split_method == "destination" and base_options.destination then
      table.insert(cmd_args, "-d")
      table.insert(cmd_args, base_options.destination)
    end

    -- Add message if provided
    if flags.m and flags.m ~= "" then
      table.insert(cmd_args, "-m")
      table.insert(cmd_args, flags.m)
    end

    -- Add tool if provided
    if flags.t and flags.t ~= "" then
      table.insert(cmd_args, "--tool")
      table.insert(cmd_args, flags.t)
    end

    -- Always use interactive mode for splits
    table.insert(cmd_args, "--interactive")

    -- Execute the command
    vim.notify("Executing: " .. final_command, vim.log.levels.INFO)

    local success = commands.execute_interactive_with_immutable_prompt(cmd_args, create_interactive_callbacks("split"))
    if not success then
      vim.notify("Failed to start split", vim.log.levels.ERROR)
    end
  elseif command_type == "duplicate" then
    table.insert(cmd_args, "duplicate")

    -- Add source commits (pre-selected commits or cursor commit)
    if selected_commits and #selected_commits > 0 then
      -- Use pre-selected commits from multi-select
      vim.notify(string.format("DEBUG: Using %d pre-selected commits: %s", #selected_commits, table.concat(selected_commits, ", ")), vim.log.levels.INFO)
      for _, commit_id in ipairs(selected_commits) do
        table.insert(cmd_args, commit_id)
      end
    else
      -- Use cursor commit when flow started
      local source_commit = cursor_commit or "@"
      vim.notify(string.format("DEBUG: Using cursor commit: %s", source_commit), vim.log.levels.INFO)
      table.insert(cmd_args, source_commit)
    end

    -- Add target options based on user selection
    local target_type = base_options.target_type
    if target_type == "destination" and base_options.destination then
      table.insert(cmd_args, "--destination")
      table.insert(cmd_args, base_options.destination)
    elseif target_type == "insert_after" and base_options.destination then
      table.insert(cmd_args, "--insert-after")
      table.insert(cmd_args, base_options.destination)
    elseif target_type == "insert_before" and base_options.destination then
      table.insert(cmd_args, "--insert-before")
      table.insert(cmd_args, base_options.destination)
    end
    -- If target_type is "none", no target arguments are added (quick duplicate)

    -- Execute the command
    vim.notify("Executing: " .. final_command, vim.log.levels.INFO)
    commands.execute_async(cmd_args, {}, create_async_callback("Duplicate"))
  else
    -- Fallback for other commands not yet implemented
    vim.notify("Command not yet implemented: " .. final_command, vim.log.levels.WARN)
  end
end

-- Start duplicate flow with pre-selected commits
M.start_duplicate_flow_with_commits = function(selected_commits, parent_win_id)
  vim.notify(string.format("DEBUG: Starting duplicate flow with %d commits: %s", #selected_commits, table.concat(selected_commits, ", ")), vim.log.levels.INFO)
  
  -- Start the duplicate flow normally (this will show step 1)
  if not M.start_flow("duplicate", parent_win_id) then
    vim.notify("Failed to start duplicate flow", vim.log.levels.ERROR)
    return
  end
  
  -- Store the selected commits in the state
  M.state.selected_commits = selected_commits
  vim.notify(string.format("DEBUG: Stored %d commits in flow state: %s", #M.state.selected_commits, table.concat(M.state.selected_commits, ", ")), vim.log.levels.INFO)
  
  -- Set base options to indicate we already selected multiple sources
  M.state.base_options.source_type = "multiple"
  
  -- Close the current menu (step 1) and advance to step 2
  if inline_menu.is_active() then
    inline_menu.close()
  end
  
  -- Skip to step 2 (duplicate options)
  M.state.step = 2
  
  -- Show step 2 (duplicate options menu)
  vim.schedule(function()
    M.show_current_step()
  end)
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
    cursor_commit = nil,
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

