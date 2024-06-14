local utf = require'lua-utf8'

local M = {}

function M.window_center(input_width)
  return {
    relative = "editor",
    row = vim.api.nvim_list_uis()[1].height / 2 - 1,
    col = vim.api.nvim_list_uis()[1].width / 2 - input_width / 2,
  }
end

function M.under_cursor(_)
  return {
    relative = "cursor",
    row = 1,
    col = 0,
  }
end

function M.input(opts, on_confirm, win_config)
  local prompt = opts.prompt or "Input: "
  local default = opts.default or ""

  local default_width = utf.len(default) + 10
  local prompt_width = opts.prompt_width or utf.len(prompt) + 10
  local prompt_height = opts.prompt_height or 1
  local input_width = default_width > prompt_width and default_width or prompt_width

  local default_win_config = {
    focusable = true,
    style = "minimal",
    border = { "┏", "━" ,"┓", "┃", "┛", "━", "┗", "┃" },
    width = input_width,
    height = prompt_height,
    title = ' '..prompt..' ',
  }

  if prompt == "New Name: " then
    default_win_config = vim.tbl_deep_extend("force", default_win_config, M.under_cursor(input_width))
  else
    default_win_config = vim.tbl_deep_extend("force", default_win_config, M.window_center(input_width))
  end

  win_config = vim.tbl_deep_extend("force", default_win_config, win_config)

  local buffer = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_keymap(buffer, 'n', '<Left>', '', { silent = true })
  vim.api.nvim_buf_set_keymap(buffer, 'n', '<Right>', '', { silent = true })
  vim.api.nvim_buf_set_keymap(buffer, 'n', '<Up>', '', { silent = true })
  vim.api.nvim_buf_set_keymap(buffer, 'n', '<Down>', '', { silent = true })
  vim.api.nvim_buf_set_text(buffer, 0, 0, 0, 0, { default })
  local window = vim.api.nvim_open_win(buffer, true, win_config)

  vim.api.nvim_win_set_cursor(window, { 1, vim.fn.strlen(default) + 1 })
  vim.cmd('startinsert')

  vim.keymap.set({ 'n', 'i', 'v' }, '<cr>', function()
    local lines = vim.api.nvim_buf_get_lines(buffer, 0, 1, false)
    if utf.len(lines[1]) > 3 and on_confirm then
      on_confirm(lines[1])
    end
    vim.api.nvim_win_close(window, true)
    vim.cmd('stopinsert')
  end, { buffer = buffer })

  vim.keymap.set("n", "<esc>", function() vim.api.nvim_win_close(window, true) end, { buffer = buffer })
  vim.keymap.set("n", "q", function() vim.api.nvim_win_close(window, true) end, { buffer = buffer })
end

return M
