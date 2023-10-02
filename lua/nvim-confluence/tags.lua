local api = require"nvim-confluence.api"
local db = require"nvim-confluence.database"
local pages = require"nvim-confluence.pages"
local term = require "fzf-commands-windows.term"
local utf = require'lua-utf8'
local util = require"nvim-confluence.util"
local utils = require "fzf-commands-windows.utils"
local fn, nvim = utils.helpers()
local tags = {}

tags.render = function(tip)
  local data = db:tag_choose()
  local results = {}

  if type(tip) == 'string' then
    table.insert(results, 1, tip)
  end
  if type(tip) == 'table' then
    for _, v in pairs(tip) do
      table.insert(results, 1, v)
    end
  end

  for _, v in pairs(data) do
    table.insert(results, string.format("%-24s", term.green .. tostring(v.id) .. term.reset) ..
                          string.format("%s", term.blue .. v.name .. term.reset))
  end
  return results
end

tags.match = function(string)
  local id, name = utf.match(string, '(%d+)%s*(%w+)')
  return id, name
end

tags.tag = function(opts)
  local opts = utils.normalize_opts(opts)

  coroutine.wrap(function()
    local choices_tags = opts.fzf(tags.render({ 'Select tags to apply to selected (next screen) pages', term.green .. 'CTRL-B' .. term.reset .. ' to push query text as tag to DB'}),
      (term.fzf_colors .. ' --bind "ctrl-b:execute-silent(cmd /c for /f %i in ({q}) do @echo INSERT INTO tags (id,name) VALUES(' .. os.date("%j%H%M%S") .. ', \'%~i\') | sqlite3 -utf8 ' .. fn.expand('~') ..  '\\confluence_db.db)+abort" --header-lines=2 --multi --ansi --prompt="Confluence tags> "'))
    if not choices_tags then return end

    local _tags = {}
    for _, tag in pairs(choices_tags) do
      local id, name = tags.match(tag)
      table.insert(_tags, name)
    end

    local choices_pages = opts.fzf(pages.render(),
      (term.fzf_colors .. ' --delimiter="' .. util.delim .. '" --header="Tags: +'.. table.concat(_tags, ' +') ..
                          '" --expect=ctrl-b --multi --ansi --prompt="Confluence pages> "'))
    if not choices_pages then return end

    if choices_pages[1] == "" then
      for i=2, #choices_pages do
        local pageid, space, title = pages.match(choices_pages[i])
        api:tag(pageid, title, _tags)
      end
    end
    if choices_pages[1] == "ctrl-b" then
      for i=2, #choices_pages do
        local pageid, space, title = pages.match(choices_pages[i])
        api:tag_remove(pageid, title, tags)
      end
    end
  end)()
end

return tags
