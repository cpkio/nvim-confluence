local term = require "fzf-commands-windows.term"
local db = require"nvim-confluence.database"
local api = require"nvim-confluence.api"
local util = require"nvim-confluence.util"
local pages = require"nvim-confluence.pages"
local utils = require "fzf-commands-windows.utils"
local utf = require'lua-utf8'
local fn, nvim = utils.helpers()

local comments = {}

comments.comment = function(opts)
  local buffercontent = nvim.buf_get_lines(0, 0, -1, true)
  local opts = utils.normalize_opts(opts)
  local command = function()
    local data = db:pg_choose()
    local results = {}

    local tip = term.green .. 'ENTER' .. term.reset ..
                ' to select ' .. term.red .. 'commented article' .. term.reset .. ' for current buffer.'

    table.insert(results, 1, tip)

    for _, v in pairs(data) do
      table.insert(results, string.format("%-24s", term.green .. tostring(v.id) .. term.reset) ..
                            string.format("%-18s", term.red .. v.space .. term.reset) ..
                            string.format("%s", term.blue .. util.unescape(v.title) .. term.reset))
    end
    return results
  end


  coroutine.wrap(function ()
    local choice = opts.fzf(command(),
      (term.fzf_colors .. ' --header-lines=1 --ansi --prompt="Select commented page> "'))
    if not choice then return end

    local page, space, title = pages.match(choice[1])
    api:post_comment(page, buffercontent)
    vim.notify("Комментарий к статье «" .. title  .. "» опубликован ")

  end)()
end

return comments
