local has_sqlite, sqlite = pcall(require, 'sqlite')
local term = require"fzf-commands-windows.term"
local util = require"nvim-confluence.util"
local api = require"nvim-confluence.api"

local confldb = sqlite {
  uri = vim.fn.expand('~')..'/confluence_db.db',
  opts = {
    cache_size = 1048576,
    page_size = 65536,
    threads = 1,
    synchronous = 'OFF',
  },
  pages = {
    id = { 'int', required = true, unique = true, primary = true },
    title = 'text',
    space = 'text'
  },
  tags = {
    id = { 'int', required = true, unique = true, primary = true },
    name = 'text',
  },
  pages_to_tags = {
    id = true,
    pageid = { 'text', reference = 'pages.id' },
    pagetag = { 'text', reference = 'tags.id' }
  },
  pages_cache = {
    pagestring = 'text'
  }
}

local pages = confldb.pages
local tags = confldb.tags
local p2t = confldb.pages_to_tags
local cache = confldb.pages_cache

local db = {}

function db.new()
  return setmetatable({}, { __index = db })
end

function db:cache_insert(s)
  return cache:insert({ pagestring = s })
end

function db:cache_load()
  return cache:get()
end

function db:cache_drop()
  cache:drop()
end

function db:cache_recreate()
  local data = pages:get()
  local results = {}
  for _, v in pairs(data) do
    local _tags = p2t:get{ where = { pageid = tostring(v.id) }} or {}
    local tglist = {}
    if #_tags > 0 then
      local tglist_basic = {}
      for _, t in pairs(_tags) do
        local tagentry = tags:sort{ where = { id = t.pagetag }}
        table.insert(tglist_basic, tagentry[1].name)
      end
      table.sort(tglist_basic)
      for _, s in pairs(tglist_basic) do
        table.insert(tglist, term.brightcyan .. s .. term.reset)
      end
    end
    table.insert(results, string.format("%-21s", term.green .. tostring(v.id) .. ' ' .. term.reset) .. util.delim ..
                          string.format("%-14s", term.red .. v.space .. term.reset) .. util.delim ..
                          string.format("%s", term.blue .. util.unescape(v.title) .. term.reset) .. util.delim ..
                          string.format("%s", table.concat(tglist, util.delim))
    )
  end
  cache:drop()
  for _, v in pairs(results) do
    cache:insert{ pagestring = util.escape(v) }
  end
end

function db:pg_insert(id, title, space)
  pages:insert({
    id = id,
    title = title,
    space = space
  })
end

function db:pg_choose(pid)
  if pid then
    return pages:get{ where = { id = pid }}
  else
    return pages:get()
  end
end

function db:pg_choose_title(text)
  if text then
    return pages:get{ contains = { title = '*'..text..'*' }}
  else
    return
  end
end

function db:pg_update(id, title, space)
  pages:update({
    where = { id = id },
    set = {
      title = title,
      space = space
    }
  })
end

function db:pg_delete(id)
  pages:delete({
    where = { id = id }
  })
end

function db:pg_drop()
  pages:drop()
end

function db:page2tag_insert(pid, tid)
  p2t:insert({
    pageid = pid,
    pagetag = tid
  })
end

function db:page2tag_select(pid)
  return p2t:get{ where = { pageid = pid } }
end

function db:page2tag_drop()
  p2t:drop()
end

function db:tag_insert(id, name)
  tags:insert({
    id = id,
    name = name
  })
end

function db:tag_choose(tid)
  if tid then
    return tags:sort({ where = { id = tid }})
  else
    return tags:sort({}, "name")
  end
end

function db:tag_drop()
  tags:drop()
end

local function insert_if_absent(tag)
  local exists = tags:get{ where = { id = tag.id }}
  if #exists == 1 then
  end
  if #exists == 0 then
    tags:insert({
      id = tag.id,
      name = tag.name
    })
  end
end

db.push = function(page)
  if page == nil then return nil end
  local space = page.space.key
  pages:insert({
    id = page.id,
    title = page.title,
    space = space
  })
  if #page.metadata.labels.results then
    for _,tag in pairs(page.metadata.labels.results) do
      insert_if_absent(tag)
      p2t:insert({
        pageid = page.id,
        pagetag = tag.id
      })
    end
  end
end

db.update = function()
  local data = api:get()
  local pool = data.results
  local nextpage = data._links.next

  while nextpage ~= nil do
    local page = api:get(nextpage)
    nextpage = page._links.next
    pool = table.merge(pool, page.results)
  end

  pool = vim.tbl_filter(function(page) return page.status == 'current' end, pool)

  vim.notify("Got " .. #pool .. " Confluence pages")

  db:page2tag_drop()
  db:tag_drop()
  db:pg_drop()

  for _, page in pairs(pool) do
    if type(page.title) ~= 'string' then
      page.title = ''
    else
      page.title = util.escape(page.title)
    end
    db.push(page)
  end

  vim.notify("SQLite DB backend has been updated", 3, {})
  coroutine.wrap(function()
    db:cache_recreate()
  end)()
end

return db
