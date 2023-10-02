vim.api.nvim_create_user_command('ConfluenceUpdate', function()
  require('nvim-confluence').db.update()
end, { desc = 'Update SQLite database from Confluence API request' })

vim.api.nvim_create_user_command('ConfluenceInstallPandocFilter', function()
  require('nvim-confluence').install()
end, { desc = 'Install no-header-ids.lua to Pandoc Appdata Folder' })

vim.api.nvim_create_user_command('ConfluenceVimwikiToHtmlTransform', function()
  require('nvim-confluence').vimwiki_transform()
end, { desc = 'Transform current buffer Vimwiki content to HTML with Lua-filter applied' })

vim.api.nvim_create_user_command('ConfluenceMarkdownToHtmlTransform', function()
  require('nvim-confluence').markdown_transform()
end, { desc = 'Transform current buffer Markdown content to HTML with Lua-filter applied' })
