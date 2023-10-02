local api = require"nvim-confluence.api"
local db = require"nvim-confluence.database"
local term = require "fzf-commands-windows.term"
local utf = require'lua-utf8'
local util = require"nvim-confluence.util"
local utils = require "fzf-commands-windows.utils"
local fn, nvim = utils.helpers()
local pages = {}

pages.render = function(tip)
  local data = db:cache_load()
  local results = {}

  for _, v in pairs(data) do
    local u = util.unescape(v.pagestring)
    table.insert(results, u)
  end
  if type(tip) == 'string' then
    table.insert(results, 1, tip)
  end
  if type(tip) == 'table' then
    for _, v in pairs(tip) do
      table.insert(results, 1, v)
    end
  end

  return results
end

pages.match = function(string)
  local page, space, title = utf.match(util.unescape(string), '^(%d+)%s+(%u+)%s+([^'.. util.delim .. ']+)')
  return page, space, title
end

local function cleanup(text)
  local regex1 = '<ac:link>%s*<ri:page%s+ri:space%-key="([^"]+)"%s+ri:content%-title="([^"]+)"%s*/>%s*</ac:link>'
  local regex1a = '<ac:link>%s*<ri:page%s+ri:content%-title="([^"]+)"%s+ri:space%-key="([^"]+)"%s*/>%s*</ac:link>'
  local regex2 = '<ac:link>%s*<ri:page%s+ri:content%-title="([^"]+)"%s*/>%s*</ac:link>'
  local regex3 = '<ac:parameter%s*[^>]*>%s*([^<]+)%s*</ac:parameter>'
  local regex4 = '<ac:image%s*[^>]*>%s*<ri:attachment ri:filename="([^"]+)"%s*/>%s*</ac:image>'
  local regex5 = '%+%-+%p+%+'
  local text = utf.gsub(text, regex1, '<a>%1:%2</a>')
  local text = utf.gsub(text, regex1a, '<a>%1:%2</a>')
  local text = utf.gsub(text, regex2, '<a>%1</a>')
  local text = utf.gsub(text, regex3, '<p>param:%1</p>')
  local text = utf.gsub(text, regex4, '<p>image:%1</p>')
  -- local text = string.gsub(text, regex5, '')
  return text
end

local function getcontent(page)
  local data = api:get("/rest/api/content/".. page ..
                           "?expand=body.storage")
  local code = data.body.storage.value
  return code
end

local function getversion(page)
  local data = api:get("/rest/api/content/".. page ..
                           "?expand=version")
  local version = data.version.number
  return version
end

pages.load = function(opts)
  local opts = utils.normalize_opts(opts)
  local nth
  if opts.nth then
    nth = '--nth='..opts.nth
  else
    nth = ''
  end

  coroutine.wrap(function ()
    local choices = opts.fzf(pages.render(
      { term.green .. 'ENTER' .. term.reset .. ' to open text-only version. ',
        term.green .. 'CTRL-T' .. term.reset .. ' to open formatted HTML code. ' ..
        term.green .. 'CTRL-Y' .. term.reset .. ' to open source HTML code. ' ..
        term.green .. 'CTRL-P' .. term.reset .. ' to paste links.',
        term.green .. 'ALT-M' .. term.reset .. ' to move pages. ' ..
        term.green .. 'ALT-R' .. term.reset .. ' to rename pages. ' ..
        term.green .. 'ALT-O' .. term.reset .. ' to open Web pages.'
      }
    ),
      (term.fzf_colors .. ' --delimiter="' .. util.delim .. '" ' .. nth .. ' --header-lines=3 --multi --expect=ctrl-t,ctrl-y,ctrl-p,alt-m,alt-r,alt-o --ansi --prompt="Confluence pages> "'))
    if not choices then return end

    local choice_parent, parentpage, parenttitle
    if choices[1] == "alt-m" then

        choice_parent = opts.fzf(pages.render(
          term.green .. 'ENTER' .. term.reset .. ' to select ' ..
          term.red .. 'parent page' .. term.reset .. ' for previously selected pages.'
        ),
          (term.fzf_colors .. ' --delimiter="' .. util.delim .. '" --nth=1 --header-lines=1 --ansi --prompt="Select parent page> "'))

        if not choice_parent then
          return
        else
          parentpage, _, parenttitle = pages.match(choice_parent[1])
        end
    end

    for i = 2, #choices do
      local page, space, title = pages.match(choices[i])

      if choices[1] == "" then
        local text = getcontent(page)
        local code = api:convert(text)
        util.pipe(code.value, vim.trim(page .. ' ' .. title), 'pandoc', {
          '--eol=lf',
          '--wrap=preserve',
          '--columns=1024',
          '-f',
          'html',
          '-t',
          'asciidoc'
        })
      end

      if choices[1] == "alt-o" then
        os.execute('start ' .. os.getenv('CONFLUENCE_HOST') .. '/pages/viewpage.action?pageId=' .. page)
      end

      if choices[1] == "ctrl-t" then
        local code = getcontent(page)
        local xml = require'LuaXML'
        local decoded = xml.eval(
          '<phony>' ..
               code ..
          '</phony>'
        )
        decoded:iterate( -- предобработка, связанная с тем, что LuaXML отбрасывает `<![CDATA[` и `]]>` при десериализации в таблицу и сериализации обратно в текст
          function(var, depth)
            if var:tag() == 'ac:plain-text-body' then
              var[1] = '<![CDATA[' .. var[1] .. ']]>'
            end
            return true
          end,
        nil, nil, nil, true, 10000)

        util.pipe(xml.decode(xml.str(decoded)), vim.trim(page .. ' ' .. title), nil, nil, function(t) local _t = fn.split(t, [[\n]], true); return table.slice(_t, 2, #_t-2) end) -- отрезаем <phony></phony>
      end

      if choices[1] == "ctrl-y" then
        local code = getcontent(page)
        util.pipe(code, vim.trim(page .. ' ' .. title), nil, nil, function(t) return fn.split(t, [[\n]], true) end)
      end

      if choices[1] == "ctrl-p" then
        local link = '['..title..']('..os.getenv('CONFLUENCE_HOST')..'/pages/viewpage.action?pageId='..page..')'
        nvim.buf_set_lines(0, -1, -1, false, {link})
      end

      if choices[1] == "alt-m" then
        api:move(page, parentpage, title, getversion(page) + 1, parenttitle)
      end

      if choices[1] == "alt-r" then
        local version = tonumber(getversion(page))

        vim.ui.input({ prompt = 'Введите новый заголовок для статьи «' .. title .. '»:', default = vim.trim(title) }, function(newtitle)
            api:rename(page, title, newtitle, version + 1)
            vim.notify(util.wrap("Статья «" .. title  .. "» переименована в «" .. newtitle .. "» "))
        end)
      end

      vim.notify("Статья «" .. title  .. "» загружена ")
    end
  end)()
end

pages.create = function(opts)
  local buffercontent = nvim.buf_get_lines(0, 0, -1, true)
  local opts = utils.normalize_opts(opts)

  coroutine.wrap(function ()
    local choice = opts.fzf(pages.render(
      term.green .. 'ENTER' .. term.reset .. ' to select ' ..
      term.red .. 'parent page' .. term.reset .. ' for current buffer.'
    ),
      (term.fzf_colors .. ' --delimiter="' .. util.delim .. '" --nth=1 --header-lines=1 --ansi --prompt="Select parent page> "'))
    if not choice then return end

    local parent, space, _ = pages.match(choice[1])
    vim.ui.input({ prompt = 'Введите заголовок для новой статьи:', prompt_width = 48 }, function(pagetitle)
      api:post(space, pagetitle, parent, buffercontent)
      vim.notify("Статья «" .. pagetitle  .. "» загружена ")
    end)

  end)()
end

pages.update = function(opts)
  local buffercontent = nvim.buf_get_lines(0, 0, -1, true)
  local opts = utils.normalize_opts(opts)

  coroutine.wrap(function ()
    local choice = opts.fzf(pages.render(
      term.green .. 'ENTER' .. term.reset ..
      ' to select ' .. term.red .. ' page to update' .. term.reset ..
      ' with current buffer.'
    ),
      (term.fzf_colors .. '--delimiter="' .. util.delim .. '" --nth=1 --header-lines=1 --ansi --prompt="Select page to replace> "'))
    if not choice then return end

    local replacedpage, space, title = pages.match(choice[1])
    vim.notify('Загружаем текущую версию статьи…')
    local version = tonumber(getversion(replacedpage))

    vim.ui.input({ prompt = 'Введите заголовок для новой редакции статьи:', default = vim.trim(title) }, function(pagetitle)
      vim.ui.input({ prompt = 'Введите комментарий к правке в '..pagetitle..':', prompt_width = 75, prompt_height = 3 } , function(message)
        api:put(space, pagetitle, buffercontent, replacedpage, version + 1, util.wrap(message, 78, 0))
        vim.notify(util.wrap("Статья «" .. pagetitle  .. "» загружена с комментарием «" .. message .. "» "))
      end)
    end)

  end)()
end

pages.delete = function(opts)
  local opts = utils.normalize_opts(opts)
  local nth = ''
  if opts.nth then
    nth = '--nth='..opts.nth
  end

  coroutine.wrap(function()
    local choices_pages = opts.fzf(pages.render(
      {'Select pages for ' .. term.red .. 'DELETION' .. term.reset,
       term.red .. 'CTRL-L' .. term.reset .. ' to delete pages.',
       term.red .. 'CTRL-W' .. term.reset .. ' to delete page tree.'}
    ),
      (term.fzf_colors .. ' --delimiter="' .. util.delim .. '" ' .. nth .. ' --expect=ctrl-l,ctrl-w --header-lines=3 --multi --ansi --prompt="Confluence tags> "'))
    if not choices_pages then return end

    if choices_pages[1] == "" then
      vim.notify(util.wrap("No pages deleted. Press CTRL-L to confirm deletion."), 3)
    end

    if choices_pages[1] == "ctrl-l" then
      for i = 2, #choices_pages do
        local pageid, space, title = pages.match(choices_pages[i])
        api:delete(pageid)
        vim.notify(util.wrap("Page «" .. title .. "» (" .. space ..  ") deleted"), 3)
      end
    end

    if choices_pages[1] == "ctrl-w" then
      for i = 2, #choices_pages do
        local pageid, space, title = pages.match(choices_pages[i])
        api:delete_tree(pageid)
        vim.notify(util.wrap("Page tree from «" .. title .. "» deleted"), 3)
      end
    end
  end)()
end

return pages
