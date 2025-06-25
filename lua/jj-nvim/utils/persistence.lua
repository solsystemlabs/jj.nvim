local M = {}

-- Get the path for persistent storage
local function get_storage_path()
  local data_path = vim.fn.stdpath('data')
  return data_path .. '/jj-nvim-settings.json'
end

-- Load settings from disk
M.load = function()
  local storage_path = get_storage_path()
  
  if vim.fn.filereadable(storage_path) == 0 then
    return {}
  end
  
  local ok, content = pcall(vim.fn.readfile, storage_path)
  if not ok then
    return {}
  end
  
  local json_str = table.concat(content, '\n')
  if json_str == '' then
    return {}
  end
  
  local ok_decode, settings = pcall(vim.json.decode, json_str)
  if not ok_decode then
    vim.notify('Failed to parse jj-nvim settings file', vim.log.levels.WARN)
    return {}
  end
  
  return settings or {}
end

-- Save settings to disk
M.save = function(settings)
  local storage_path = get_storage_path()
  
  local ok, json_str = pcall(vim.json.encode, settings)
  if not ok then
    vim.notify('Failed to encode jj-nvim settings', vim.log.levels.ERROR)
    return false
  end
  
  -- Ensure the directory exists
  local dir = vim.fn.fnamemodify(storage_path, ':h')
  if vim.fn.isdirectory(dir) == 0 then
    vim.fn.mkdir(dir, 'p')
  end
  
  local ok_write = pcall(vim.fn.writefile, {json_str}, storage_path)
  if not ok_write then
    vim.notify('Failed to write jj-nvim settings file', vim.log.levels.ERROR)
    return false
  end
  
  return true
end

return M