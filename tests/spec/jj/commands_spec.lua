local mock_jj = require('tests.helpers.mock_jj')
local test_utils = require('tests.helpers.test_utils')

describe('jj commands', function()
  local commands
  local mock_system
  local mock_notify
  
  before_each(function()
    -- Reset module cache
    package.loaded['jj-nvim.jj.commands'] = nil
    commands = require('jj-nvim.jj.commands')
    
    -- Set up mocks
    mock_notify = mock_jj.mock_vim_notify()
  end)
  
  after_each(function()
    if mock_system then
      mock_system.restore()
    end
    if mock_notify then
      mock_notify.restore()
    end
  end)

  describe('execute', function()
    it('should execute successful jj commands', function()
      mock_system = mock_jj.mock_vim_system({
        {
          code = 0,
          stdout = "success output",
          stderr = ""
        }
      })
      
      local result, err = commands.execute({'status'})
      
      assert.is_nil(err)
      assert.is_not_nil(result)
      assert.equals("success output", result)
    end)
    
    it('should handle command failures', function()
      mock_system = mock_jj.mock_vim_system({
        {
          code = 1,
          stdout = "",
          stderr = "Command failed"
        }
      })
      
      local result, err = commands.execute({'invalid-command'})
      
      assert.is_nil(result)
      assert.is_not_nil(err)
      assert.equals("Command failed", err)
    end)
    
    it('should handle command timeout', function()
      -- Mock a timeout scenario
      mock_system = mock_jj.mock_vim_system({})
      
      -- Override mock to return nil (timeout)
      vim.system = function(cmd, opts)
        return {
          wait = function()
            return nil  -- Simulate timeout
          end
        }
      end
      
      local result, err = commands.execute({'log'})
      
      assert.is_nil(result)
      assert.is_not_nil(err)
      test_utils.assert_contains(err, "timed out")
    end)
    
    it('should accept string arguments', function()
      mock_system = mock_jj.mock_vim_system({
        {
          code = 0,
          stdout = "log output",
          stderr = ""
        }
      })
      
      local result, err = commands.execute('log --limit 5')
      
      assert.is_nil(err)
      assert.is_not_nil(result)
      assert.equals("log output", result)
    end)
    
    it('should accept table arguments', function()
      mock_system = mock_jj.mock_vim_system({
        {
          code = 0,
          stdout = "log output",
          stderr = ""
        }
      })
      
      local result, err = commands.execute({'log', '--limit', '5'})
      
      assert.is_nil(err)
      assert.is_not_nil(result)
      assert.equals("log output", result)
    end)
  end)

  describe('error handling and notifications', function()
    it('should show error notifications by default', function()
      mock_system = mock_jj.mock_vim_system({
        {
          code = 1,
          stdout = "",
          stderr = "Test error message"
        }
      })
      
      local result, err = commands.execute({'invalid'})
      
      assert.is_nil(result)
      assert.is_not_nil(err)
      
      local notifications = mock_notify.get_notifications()
      assert.is_true(#notifications > 0)
      
      local error_notification = notifications[1]
      assert.equals(vim.log.levels.ERROR, error_notification.level)
      test_utils.assert_contains(error_notification.message, "Test error message")
    end)
    
    it('should suppress notifications when silent option is true', function()
      mock_system = mock_jj.mock_vim_system({
        {
          code = 1,
          stdout = "",
          stderr = "Test error message"
        }
      })
      
      local result, err = commands.execute({'invalid'}, { silent = true })
      
      assert.is_nil(result)
      assert.is_not_nil(err)
      
      local notifications = mock_notify.get_notifications()
      assert.equals(0, #notifications)
    end)
    
    it('should show timeout notifications by default', function()
      mock_system = mock_jj.mock_vim_system({})
      
      -- Override mock to return nil (timeout)
      vim.system = function(cmd, opts)
        return {
          wait = function()
            return nil
          end
        }
      end
      
      local result, err = commands.execute({'log'})
      
      assert.is_nil(result)
      assert.is_not_nil(err)
      
      local notifications = mock_notify.get_notifications()
      assert.is_true(#notifications > 0)
      
      local timeout_notification = notifications[1]
      assert.equals(vim.log.levels.ERROR, timeout_notification.level)
      test_utils.assert_contains(timeout_notification.message, "timed out")
    end)
    
    it('should suppress timeout notifications when silent', function()
      mock_system = mock_jj.mock_vim_system({})
      
      vim.system = function(cmd, opts)
        return {
          wait = function()
            return nil
          end
        }
      end
      
      local result, err = commands.execute({'log'}, { silent = true })
      
      assert.is_nil(result)
      assert.is_not_nil(err)
      
      local notifications = mock_notify.get_notifications()
      assert.equals(0, #notifications)
    end)
  end)

  describe('command construction', function()
    it('should construct jj commands correctly', function()
      local executed_commands = {}
      
      vim.system = function(cmd, opts)
        table.insert(executed_commands, cmd)
        return {
          wait = function()
            return {
              code = 0,
              stdout = "success",
              stderr = ""
            }
          end
        }
      end
      
      commands.execute({'log', '--limit', '5'})
      
      assert.equals(1, #executed_commands)
      local cmd = executed_commands[1]
      
      assert.equals('jj', cmd[1])
      assert.equals('log', cmd[2])
      assert.equals('--limit', cmd[3])
      assert.equals('5', cmd[4])
    end)
    
    it('should handle empty arguments', function()
      local executed_commands = {}
      
      vim.system = function(cmd, opts)
        table.insert(executed_commands, cmd)
        return {
          wait = function()
            return {
              code = 0,
              stdout = "success",
              stderr = ""
            }
          end
        }
      end
      
      commands.execute({})
      
      assert.equals(1, #executed_commands)
      local cmd = executed_commands[1]
      
      assert.equals(1, #cmd)
      assert.equals('jj', cmd[1])
    end)
    
    it('should split string arguments correctly', function()
      local executed_commands = {}
      
      vim.system = function(cmd, opts)
        table.insert(executed_commands, cmd)
        return {
          wait = function()
            return {
              code = 0,
              stdout = "success",
              stderr = ""
            }
          end
        }
      end
      
      commands.execute('log --limit 5 --no-pager')
      
      assert.equals(1, #executed_commands)
      local cmd = executed_commands[1]
      
      assert.equals('jj', cmd[1])
      assert.equals('log', cmd[2])
      assert.equals('--limit', cmd[3])
      assert.equals('5', cmd[4])
      assert.equals('--no-pager', cmd[5])
    end)
  end)

  describe('system integration', function()
    it('should use vim.system with correct options', function()
      local system_calls = {}
      
      vim.system = function(cmd, opts)
        table.insert(system_calls, { cmd = cmd, opts = opts })
        return {
          wait = function()
            return {
              code = 0,
              stdout = "success",
              stderr = ""
            }
          end
        }
      end
      
      commands.execute({'status'})
      
      assert.equals(1, #system_calls)
      local call = system_calls[1]
      
      assert.is_table(call.opts)
      assert.is_true(call.opts.text)
    end)
    
    it('should handle system integration correctly', function()
      -- Test that the commands module properly integrates with vim.system
      local system_called = false
      local original_system = vim.system
      
      vim.system = function(cmd, opts)
        system_called = true
        assert.equals('jj', cmd[1])
        assert.equals('status', cmd[2])
        assert.is_table(opts)
        assert.is_true(opts.text)
        
        return {
          wait = function()
            return {
              code = 0,
              stdout = "success",
              stderr = ""
            }
          end
        }
      end
      
      local result, err = commands.execute({'status'})
      
      -- Restore original function
      vim.system = original_system
      
      assert.is_true(system_called)
      assert.is_not_nil(result)
      assert.is_nil(err)
    end)
  end)
  
  describe('real jj integration', function()
    it('should work with real jj status command when in jj repo', function()
      test_utils.skip_if_not_jj_repo()
      
      local result, err = commands.execute({'status'}, { silent = true })
      
      -- Should either succeed or fail gracefully
      if err then
        assert.is_string(err)
      else
        assert.is_string(result)
      end
    end)
    
    it('should handle invalid jj commands gracefully', function()
      local result, err = commands.execute({'this-command-does-not-exist'}, { silent = true })
      
      assert.is_nil(result)
      assert.is_not_nil(err)
      assert.is_string(err)
    end)
  end)
end)