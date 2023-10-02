local api = require"nvim-confluence.api"
local db = require"nvim-confluence.database"

local term = require "fzf-commands-windows.term"
local utils = require "fzf-commands-windows.utils"
local util = require"nvim-confluence.util"


local utf = require'lua-utf8'
local fn, nvim = utils.helpers()

vim.ui.input = function(opts, on_confirm)
  require('nvim-confluence.input').input(opts, on_confirm, {})
end

local nconfluence = {}

nconfluence.pages = require"nvim-confluence.pages"
nconfluence.tags = require"nvim-confluence.tags"
nconfluence.comments = require"nvim-confluence.comments"
nconfluence.db = require"nvim-confluence.database"


nconfluence.vimwiki_transform = function()
  if vim.bo.filetype ~= 'vimwiki' then
    vim.notify('Current buffer is not Vimwiki, unable to transform ', 4)
    return
  end
  util.pipe(table.concat(nvim.buf_get_lines(0, 0, -1, true), '\n'),
    fn.fnamemodify(nvim.buf_get_name(0), ':t:r') .. '.html',
    'pandoc31',
    {
        '--eol=lf',
        '--lua-filter=no-header-ids.lua',
        '--wrap=none',
        '--no-highlight',
        '-f',
        'vimwiki',
        '-t',
        'html'
    })
end

nconfluence.markdown_transform = function()
  if vim.bo.filetype ~= 'markdown' then
    vim.notify('Current buffer is not Markdown, unable to transform ', 4)
    return
  end
  util.pipe(table.concat(nvim.buf_get_lines(0, 0, -1, true), '\n'),
    fn.fnamemodify(nvim.buf_get_name(0), ':t:r') .. '.html',
    'pandoc31',
    {
        '--eol=lf',
        '--lua-filter=no-header-ids.lua',
        '--wrap=none',
        '--no-highlight',
        '-f',
        'markdown',
        '-t',
        'html'
    })
end

nconfluence.install = function()
  local pandoc_filter_code = [[
stripHeaders = function(element)
  return pandoc.Header(element.level, element.content)
end
printSpan = function(element)
  if #element.content == 0 then
    return pandoc.Space()
  end
end
Pandoc = function(doc)
  local tree = pandoc.walk_block((pandoc.Div(doc.blocks)), {
    Header = stripHeaders,
    Span = printSpan
  })
  return pandoc.Pandoc(tree.content)
end
  ]]
  local user_directory = fn.expand('~')
  local installed = fn.filereadable(user_directory .. '/Appdata/Roaming/Pandoc/Filters/no-header-ids.lua')
  if installed == 1 then return end
  if installed ~= 1 then
    local has_filters_directory = fn.isdirectory(fn.expand('~') .. '/Appdata/Roaming/Pandoc/filters/')
    if has_filters_directory == 0 then
      fn.mkdir(fn.expand('~') .. '/Appdata/Roaming/Pandoc/filters/', "p" )
    end
    local filters_writable = fn.filewritable(user_directory .. '/Appdata/Roaming/Pandoc/Filters/')
    if filters_writable == 2 then
      fn.writefile( fn.split( pandoc_filter_code, '\n' ), user_directory ..  '/Appdata/Roaming/Pandoc/Filters/no-header-ids.lua')
    end
    vim.notify('Pandoc filter written to user directory')
  end
end

return nconfluence
