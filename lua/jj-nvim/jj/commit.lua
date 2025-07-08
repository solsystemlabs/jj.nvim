local M = {}

local commands = require('jj-nvim.jj.commands')
local command_utils = require('jj-nvim.jj.command_utils')

-- Helper function to get current working copy description
local function get_current_working_copy_description()
  local buffer = require('jj-nvim.ui.buffer')
  local commits = buffer.get_commits()
  
  if not commits then
    return ""
  end
  
  for _, commit in ipairs(commits) do
    if commit.current_working_copy then
      local description = commit:get_description_text_only()
      if description and description ~= "(no description set)" then
        return description
      end
      break
    end
  end
  
  return ""
end

-- Commit working copy changes
M.commit = function(message, options)
  options = options or {}
  
  -- Build command arguments using utility function
  local common_options = {
    interactive = options.interactive,
    tool = options.tool,
    message = message and message ~= "" and message or nil
  }
  
  local specific_options = {}
  
  -- Add author options
  if options.reset_author then
    table.insert(specific_options, '--reset-author')
  end
  
  if options.author then
    table.insert(specific_options, '--author')
    table.insert(specific_options, options.author)
  end
  
  -- Add filesets/paths if specified
  if options.filesets and #options.filesets > 0 then
    for _, fileset in ipairs(options.filesets) do
      table.insert(specific_options, fileset)
    end
  end
  
  local cmd_args = command_utils.build_command_args('commit', common_options, specific_options)
  return commands.execute_with_immutable_prompt(cmd_args, { silent = options.silent })
end

-- Interactive commit
M.commit_interactive = function(options)
  options = options or {}
  
  -- Use the regular commit function with interactive option
  return M.commit(nil, vim.tbl_extend('force', options, { interactive = true }))
end

-- Commit working copy changes (action wrapper)
M.commit_working_copy = function(options, on_success)
  options = options or {}

  -- Check if there are any changes to commit
  local status = require('jj-nvim.jj.status')
  local status_content, status_err = status.get_status({ silent = true })
  if not status_content then
    vim.notify("Failed to check repository status", vim.log.levels.ERROR)
    return false
  end

  -- Check if working copy has changes
  if status_content:match("The working copy has no changes") then
    vim.notify("No changes to commit", vim.log.levels.INFO)
    return true
  end

  -- If message is provided in options, use it directly
  if options.message and options.message ~= "" then
    local result, err = M.commit(options.message, options)
    if not result then
      local error_msg = err or "Unknown error"
      if error_msg:find("not in workspace") then
        error_msg = "Not in a jj workspace"
      elseif error_msg:find("empty commit") then
        error_msg = "No changes to commit"
      end

      vim.notify(string.format("Failed to commit: %s", error_msg), vim.log.levels.ERROR)
      return false
    end

    vim.notify("Committed working copy changes", vim.log.levels.INFO)
    if on_success then on_success() end
    return true
  end

  -- Prompt user for commit message
  local current_description = get_current_working_copy_description()
  vim.ui.input({
    prompt = "Enter commit message:",
    default = current_description,
  }, function(message)
    if not message or message:match("^%s*$") then
      vim.notify("Commit cancelled - no message provided", vim.log.levels.INFO)
      return false
    end

    local result, err = M.commit(message, options)
    if not result then
      local error_msg = err or "Unknown error"
      if error_msg:find("not in workspace") then
        error_msg = "Not in a jj workspace"
      elseif error_msg:find("empty commit") then
        error_msg = "No changes to commit"
      end

      vim.notify(string.format("Failed to commit: %s", error_msg), vim.log.levels.ERROR)
      return false
    end

    vim.notify("Committed working copy changes", vim.log.levels.INFO)
    if on_success then on_success() end
    return true
  end)
end

-- Show commit options menu
M.show_commit_menu = function(parent_win_id)
  local inline_menu = require('jj-nvim.ui.inline_menu')
  local config = require('jj-nvim.config')

  -- Check if there are any changes to commit
  local status = require('jj-nvim.jj.status')
  local status_content, status_err = status.get_status({ silent = true })
  if not status_content then
    vim.notify("Failed to check repository status", vim.log.levels.ERROR)
    return false
  end

  -- Check if working copy has changes
  if status_content:match("The working copy has no changes") then
    vim.notify("No changes to commit", vim.log.levels.INFO)
    return true
  end

  -- Get commit menu keys from config
  local commit_keys = config.get('keybinds.menus.commit') or config.get('menus.commit') or {
    quick = 'q',
    interactive = 'i',
    reset_author = 'r',
    custom_author = 'a',
    filesets = 'f',
  }

  -- Define menu configuration using configurable keys
  local menu_config = {
    id = "commit",
    title = "Commit Options",
    items = {
      {
        key = commit_keys.quick,
        description = "Quick commit (prompt for message)",
        action = "quick_commit",
      },
      {
        key = commit_keys.interactive,
        description = "Interactive commit (choose changes)",
        action = "interactive_commit",
      },
      {
        key = commit_keys.reset_author,
        description = "Reset author and commit",
        action = "reset_author_commit",
      },
      {
        key = commit_keys.custom_author,
        description = "Commit with custom author",
        action = "custom_author_commit",
      },
      {
        key = commit_keys.filesets,
        description = "Commit specific files (filesets)",
        action = "fileset_commit",
      },
    }
  }

  -- Show the menu
  parent_win_id = parent_win_id or vim.api.nvim_get_current_win()

  inline_menu.show(parent_win_id, menu_config, {
    on_select = function(selected_item)
      M.handle_commit_menu_selection(selected_item)
    end,
    on_cancel = function()
      -- Menu cancelled - do nothing
    end
  })
end

-- Handle commit menu selection
M.handle_commit_menu_selection = function(selected_item)
  if selected_item.action == "quick_commit" then
    -- Quick commit with message prompt
    M.commit_working_copy({})
  elseif selected_item.action == "interactive_commit" then
    -- Interactive commit using terminal interface
    local callbacks = command_utils.create_interactive_callbacks("commit")
    local success = M.commit_interactive(callbacks)

    if not success then
      vim.notify("Failed to start interactive commit", vim.log.levels.ERROR)
    end
  elseif selected_item.action == "reset_author_commit" then
    -- Commit with reset author
    local current_description = get_current_working_copy_description()
    command_utils.prompt_for_input({
      prompt = "Enter commit message (author will be reset):",
      default = current_description,
      cancel_message = "Commit cancelled - no message provided",
      on_success = function(message)
        local result, err = M.commit(message, { reset_author = true })
        if not result then
          local error_msg = err or "Unknown error"
          vim.notify(string.format("Failed to commit: %s", error_msg), vim.log.levels.ERROR)
        else
          vim.notify("Committed with reset author", vim.log.levels.INFO)
          require('jj-nvim').refresh()
        end
      end
    })
  elseif selected_item.action == "custom_author_commit" then
    -- Commit with custom author - two-step process
    command_utils.prompt_for_input({
      prompt = "Enter author (Name <email@example.com>):",
      default = "",
      cancel_message = "Commit cancelled - no author provided",
      on_success = function(author)
        local current_description = get_current_working_copy_description()
        command_utils.prompt_for_input({
          prompt = "Enter commit message:",
          default = current_description,
          cancel_message = "Commit cancelled - no message provided",
          on_success = function(message)
            local result, err = M.commit(message, { author = author })
            if not result then
              local error_msg = err or "Unknown error"
              vim.notify(string.format("Failed to commit: %s", error_msg), vim.log.levels.ERROR)
            else
              vim.notify(string.format("Committed with author: %s", author), vim.log.levels.INFO)
              require('jj-nvim').refresh()
            end
          end
        })
      end
    })
  elseif selected_item.action == "fileset_commit" then
    -- Commit specific files
    command_utils.prompt_for_input({
      prompt = "Enter file patterns (e.g., '*.lua src/'):",
      default = "",
      cancel_message = "Commit cancelled - no file patterns provided",
      on_success = function(filesets_str)
        -- Split filesets by spaces
        local filesets = vim.split(filesets_str, "%s+")

        local current_description = get_current_working_copy_description()
        command_utils.prompt_for_input({
          prompt = "Enter commit message:",
          default = current_description,
          cancel_message = "Commit cancelled - no message provided",
          on_success = function(message)
            local result, err = M.commit(message, { filesets = filesets })
            if not result then
              local error_msg = err or "Unknown error"
              vim.notify(string.format("Failed to commit: %s", error_msg), vim.log.levels.ERROR)
            else
              vim.notify(string.format("Committed files: %s", filesets_str), vim.log.levels.INFO)
              require('jj-nvim').refresh()
            end
          end
        })
      end
    })
  end
end

return M