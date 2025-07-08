local M = {}

local commands = require("jj-nvim.jj.commands")

-- JJ git fetch operation
M.git_fetch = function(options)
	options = options or {}
	local cmd_args = { "git", "fetch" }

	-- Add remote if specified
	if options.remote then
		table.insert(cmd_args, options.remote)
	end

	-- Add branch if specified
	if options.branch then
		table.insert(cmd_args, options.branch)
	end

	return commands.execute(cmd_args, { silent = options.silent })
end

-- Async JJ git fetch operation
M.git_fetch_async = function(options, callback)
	options = options or {}
	callback = callback or function() end

	local cmd_args = { "git", "fetch" }

	-- Add remote if specified
	if options.remote then
		table.insert(cmd_args, options.remote)
	end

	-- Add branch if specified
	if options.branch then
		table.insert(cmd_args, options.branch)
	end

	commands.execute_async(cmd_args, { silent = options.silent }, callback)
end

-- JJ git push operation
M.git_push = function(options)
	options = options or {}
	local cmd_args = { "git", "push" }

	-- Add remote with --remote flag if specified
	if options.remote then
		table.insert(cmd_args, "--remote")
		table.insert(cmd_args, options.remote)
	end

	-- Add branch if specified
	if options.branch then
		table.insert(cmd_args, options.branch)
	end

	-- Add force flag if specified
	if options.force then
		table.insert(cmd_args, "--force-with-lease")
	end

	-- Add --allow-new flag if specified
	if options.allow_new then
		table.insert(cmd_args, "--allow-new")
	end

	local result, exec_err = commands.execute(cmd_args, { silent = options.silent })

	if not result then
		local error_msg = exec_err or "Unknown error"

		-- Smart confirmation for --allow-new flag
		local is_new_bookmark_error = error_msg:find("Refusing to create new remote bookmark")
			or error_msg:find("allow%-new")

		if is_new_bookmark_error and not options.allow_new then
			vim.ui.select({ "Yes", "No" }, {
				prompt = "This push would create new bookmarks. Allow pushing new bookmarks to remote?",
			}, function(choice)
				if choice == "Yes" then
					-- Retry with --allow-new flag
					local retry_options = vim.tbl_extend("force", options, { allow_new = true })
					M.git_push(retry_options)
				else
					vim.notify("Push cancelled", vim.log.levels.INFO)
				end
			end)
			return false -- Return false for the original attempt
		end

		return nil, exec_err
	end

	return result, nil
end

-- Async JJ git push operation
M.git_push_async = function(options, callback)
	options = options or {}
	callback = callback or function() end

	local cmd_args = { "git", "push" }

	-- Add remote with --remote flag if specified
	if options.remote then
		table.insert(cmd_args, "--remote")
		table.insert(cmd_args, options.remote)
	end

	-- Add branch if specified
	if options.branch then
		table.insert(cmd_args, options.branch)
	end

	-- Add force flag if specified
	if options.force then
		table.insert(cmd_args, "--force-with-lease")
	end

	-- Add --allow-new flag if specified
	if options.allow_new then
		table.insert(cmd_args, "--allow-new")
	end

	commands.execute_async(cmd_args, { silent = options.silent }, function(result, exec_err)
		if not result then
			local error_msg = exec_err or "Unknown error"

			-- Smart confirmation for --allow-new flag
			local is_new_bookmark_error = error_msg:find("Refusing to create new remote bookmark")
				or error_msg:find("allow%-new")

			if is_new_bookmark_error and not options.allow_new then
				vim.schedule(function()
					vim.ui.select({ "Yes", "No" }, {
						prompt = "This push would create new bookmarks. Allow pushing new bookmarks to remote?",
					}, function(choice)
						if choice == "Yes" then
							-- Retry with --allow-new flag
							local retry_options = vim.tbl_extend("force", options, { allow_new = true })
							M.git_push_async(retry_options, callback)
						else
							vim.notify("Push cancelled", vim.log.levels.INFO)
							callback(false, "Push cancelled by user")
						end
					end)
				end)
				return -- Don't call callback yet, wait for user response
			end

			callback(false, exec_err)
			return
		end

		callback(result, nil)
	end)
end

return M
