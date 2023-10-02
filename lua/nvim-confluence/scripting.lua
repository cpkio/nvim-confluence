local api = require'nvim-confluence.api'

local M = {}

function M.download(id)
  local data = api:get("/rest/api/content/".. id .. "?expand=body.storage")
  local code = data.body.storage.value
  local title = data.title
  local f = io.open(title .. ".html", "wb")
  f:write(code)
  f:flush(); f:close()
end

local function getversion(id)
  local data = api:get("/rest/api/content/".. id .. "?expand=version")
  return data.version.number
end

local function gettitle(id)
  local data = api:get("/rest/api/content/".. id)
  return data.title
end

function M.create(file, title, parentid)
  if not (file and parentid and title) then return end
  local f = io.open(file, 'rb')
  local content
  if f then
    content = vim.fn.split(f:read('*all'), '\n')
  else
    vim.notify('File "' .. file ..'" not found', 4)
    return
  end
  api:post('SB', title, parentid, content)
  print('Created page with title "' .. title .. '"')
end

function M.update(file, title, message)
  if not (file and title and message) then return end
  local id = string.match(file, '[^/]-/-(%d+)%s+')
  local version = tonumber(getversion(id))
  local f = io.open(file, 'rb')
  local content = vim.fn.split(f:read('*all'), '\n')
  api:put('SB', title, content, id, version + 1, message)
  print('Updated ' .. id .. ' with "' .. title .. '"')
end


function M.move(id, newparent, newtitle)
  api:move(id, newparent, newtitle, getversion(id)+1)
  print('Moved ' .. id .. ' as child of ' .. newparent)
end

function M.delete(id)
  api:delete(id)
  print('Deleted ' .. id)
end

return M
