local utf = require'lua-utf8'
local uv = vim.loop
local utils = require'fzf-commands-windows.utils'
local fn, nvim = utils.helpers()

local util = {}

util.delim = ' '

util.escape = function(content)
  return string.format("__ESCAPED__'%s'", content)
end

util.unescape = function(content)
  return content:gsub("__ESCAPED__\'(.*)\'", "%1")
end

util.wrap = function(text, width, indent)
  local splitted = fn.split(text, ' ')
  local width = width or 42
  local indent = indent or 5

  local line = {}
  local sum = 0
  local res = {}
  for _, v in ipairs(splitted) do
    if sum + utf.len(v) + 1 <= width then
      table.insert(line, v)
      sum = sum + utf.len(v) + 1
    else
      if #res == 0 then
        table.insert(res, fn.join(line, ' '))
      else
        table.insert(res, string.rep(' ', indent) .. fn.join(line, ' '))
      end
      line = { v }
      sum = utf.len(v)
    end
  end
  if #line > 0 and #res > 0 then
    table.insert(res, string.rep(' ', indent) .. fn.join(line, ' '))
  end
  if #line > 0 and #res == 0 then
    table.insert(res, fn.join(line, ' '))
  end
  return fn.join(res, '\n')
end

util.pipe = function(text, bufname, command, opts, splitter)
  local pipein = uv.new_pipe(false)
  local pipeout = uv.new_pipe(false)

  local openbuf = vim.schedule_wrap(function(data, func)
    local tempbuffer = nvim.create_buf(true, false)
    nvim.buf_set_lines(tempbuffer, 0, -1, false, func(data))
    nvim.buf_set_name(tempbuffer, bufname)
    nvim.win_set_buf(0, tempbuffer)
  end)

  if command then
    local handle, pid = uv.spawn(command, {
      args = opts,
      stdio = { pipeout, pipein },
    }, function(code, signal)
        vim.notify("exit code " .. code)
        vim.notify("exit signal " .. signal)
      end)

    local d = ''
    uv.read_start(pipein, function(err, data)
      assert(not err, err)
      if data then
        d = d .. data
      end
      if not data then
        openbuf(d, function(x) return fn.split(x, [[\n]], true) end)
      end
    end)

    uv.write(pipeout, text, nil)
    uv.shutdown(pipeout)
    uv.shutdown(pipein, function()
      uv.close(handle, function()
        vim.notify("process closed: " .. tostring(handle) .. ':' .. tostring(pid))
      end)
    end)
  else openbuf(text, splitter)
  end
end

return util
