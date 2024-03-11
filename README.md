# Nvim-Confluence — плагин для работы с Confluence из Neovim

> If I have seen further [than others], it is by standing on the shoulders of
> giants (I.Newton)

> Если я и видел дальше [других], то только потому, что стоял на плечах
> гигантов (И.Ньютон)

Этот плагин не мог бы существовать без программ, написанных замечательными
людьми:

* команды редактора [Neovim](https://neovim.io)
* [luasocks](https://github.com/lunarmodules/luasocket) и [luasec](https://github.com/brunoos/luasec)
* библиотеки SSL, собранной под Windows x64 добрым человеком в интернете (при помощи GCC или Clang)
* [lua-utf8](https://github.com/starwing/luautf8)
* [SQLite](https://sqlite.org)
* [SQLite.lua](https://github.com/kkharji/sqlite.lua)
* [fzf](https://github.com/junegunn/fzf)
* [nvim-fzf](https://github.com/vijaymarupudi/nvim-fzf)
* [nvim-notify](https://github.com/rcarriga/nvim-notify)

## Цель создания плагина

Плагин написан для упрощения работы со страницами в Confluence.

Предполагаются следующие сценарии:

* вы выгружаете десяток страниц из Confluence в HTML, массово редактируете их
  в Neovim и заливаете обратно (для случая, когда вам всё-таки приходится пока
  работать в Confluence), помечая их тэгами,

* вы выполняете миграцию из Confluence, для чего выгружаете страницы
  Confluence с одновременной трансформацией их в нужный формат через `pandoc`
  или XML-трансформер, сохраняете и подправляете по мере необходимости, чтобы
  таким образом создать материалы для нового сайта.

Реализован модуль скриптования, который позволяет выполнять массовые операции
не выходя из Neovim.

На некоторых экранах реализован множественный выбор страниц (открытие,
удаление и тэгирование), на других — нет (например, создание или обновление
множества страниц содержимым одного буфера не предусмотрено).

## Что нужно для работы

### Библиотеки

* `luasocket`,
* `luasec` (для открытия SSL-соединений),
* `lua-utf8` (для работы с русским языком),
* `xmlreader` (для преобразований выгружаемых страниц).

### Исполняемые файлы

В `PATH` должны быть доступны `fzf`, `pandoc`, `sqlite3` (включая
`sqlite3.dll`).

### Плагины для Neovim

* [SQLite.lua](https://github.com/kkharji/sqlite.lua)
* [nvim-fzf](https://github.com/vijaymarupudi/nvim-fzf)
* [nvim-notify](https://github.com/rcarriga/nvim-notify)

### Опционально

Хорошим дополнением к этому плагину являются автодополнения для замечательного
[nvim-cmp](https://github.com/hrsh7th/nvim-cmp):
[cmp-confluence-html](https://github.com/cpkio/cmp-confluence-html),
[cmp-confluence-markdown](https://github.com/cpkio/cmp-confluence-markdown)
и [cmp-confluence-vimwiki](https://github.com/cpkio/cmp-confluence-vimwiki),
которые позволяют вставлять ссылки на статьи из Confluence в форматах HTML,
Markdown или Vimwiki.

## Конвенции и недостатки

Плагин выгружает страницы в формате "Id страницы + Заголовок страницы". Эта
конвенция используется в том числе в модуле скриптования, позволяя
автоматически по имени файла определять, какую страницу обновлять, заменять
или удалять.

При выгрузке страницы из Confluence в Neovim будет создан буфер
с сответствующим именем. Однако, если в названии (заголовке) страницы есть
символы, недопустимые в имени файла в ОС Windows (`/`, `\`, `:` и возможно
другие), то сохранить такой буфер с тем же именем будет невозможно. Поменяйте
имя файла при сохранении (`:saveas`).

## Предварительная настройка

1. Установите переменную окружения `CONFLUENCE_HOST` с адресом вашего
   экземпляра Confluence. Вид: `https://example.com`.

2. Установите переменную окружения `CONFLUENCE_TOKEN` и поместите в неё ваш
   токен доступа, который создаётся в личном кабинете пользователя Confluence.

   Предполагается, что ваши полномочия в Confluence допускают создание,
   изменение и удаление страниц во всех пространствах, которые вы будете
   выгружать, а также работу с тэгами.

3. Установите переменную окружения `CONFLUENCE_SPACES`, в которой будет
   содержаться список выгружаемых пространств через точку с запятой:
   `AB;CD;DE;EF`.

4. Настройте сокращения клавиатуры Neovim для вызова следующих функций:

    * `require("nvim-confluence").tags.tag()` — окно массового добавления
      тэгов (label) на страницы. Последовательно открывается два окна: для
      выбора тэгов и для выбора страниц, помечаемых этими тэгами.

      Второе окно `fzf` по каким-то причинам открывается неактивным для ввода,
      необходимо нажать одну из клавиш `i` `I` `a` `A` для перехода
      в интерактивный режим.

    * `require("nvim-confluence").pages.load({ nth = "1" })` — окно выбора
      загружаемых страниц Confluence с поиском по id/пространству/заголовку
      страницы.

    * `require("nvim-confluence").pages.load({ nth = "2.." })` — окно выбора
      загружаемых страниц Confluence с поиском по тэгам.

    * `require("nvim-confluence").pages.load({ nth = nil })` — окно выбора
      загружаемых страниц Confluence с поиском одновременно и по
      id/пространству/заголовку страницы, и по тэгам.

    * `require("nvim-confluence").pages.create()` — окно выбора родительской
      страницы для создания новой страницы из текущего буфера (HTML).

    * `require("nvim-confluence").pages.update()` — окно выбора страницы,
      содержимое которой будет заменено содержимым текущего буфера (HTML).

    * `require("nvim-confluence").comments.comment()` — окно выбора страницы,
      к которой будет добавлен комментарий, состоящий из текста в текущем
      буфере (Markdown).

    * `require("nvim-confluence").pages.delete()` — окно удаления страниц,
      по одной или вместе со всеми дочерними.

    В функцию должны передаваться параметры открываемого `fzf`-окна:

    ```lua
    -- настройки открываемого окна fzf
    local fzfwinopts = {
        border = false,
        relative = "editor",
        width = 280,
        noautocmd = true
    }

    local fzfcmd = function(contents, opts)
    return require("fzf").fzf(contents, opts, fzfwinopts)
    end

    vim.api.nvim_set_keymap('n','<leader>c', '',  {
        desc = "",
        noremap = true, silent = true,
        callback = function()
            require("nvim-confluence").pages.load({
            fzf = fzfcmd,
            nth = "2.."
            })
        end
    })
    ```

### Пример сочетаний клавиш
```lua
local map = vim.api.nvim_set_keymap

local fzfwinopts = {
  border = false,
  relative = "editor",
  width = 280, -- избыточная ширина экрана, чтобы окно FZF открывалось на максимум
  noautocmd = true
}

local fzfcmd = function(contents, opts)
  return require("fzf").fzf(contents, opts, fzfwinopts)
end

-- CTRL-D + T = Тэгирование страниц
map('n','<C-d>t', '',  {
  desc = "",
  noremap = true, silent = true,
  callback = function()
    require("nvim-confluence").tags.tag({
      fzf = fzfcmd })
  end
})

-- CTRL-D + V = Выбор страниц с поиском по id, пространству и заголовку одновременно
map('n','<C-d>v', '',  {
  desc = "",
  noremap = true, silent = true,
  callback = function()
    require("nvim-confluence").pages.load({
      fzf = fzfcmd,
      nth = "1"
    })
  end
})

-- CTRL-D + SHIFT-V = Выбор страниц с поиском по тэгам (labels) страниц
map('n','<C-d>V', '',  {
  desc = "",
  noremap = true, silent = true,
  callback = function()
    require("nvim-confluence").pages.load({
      fzf = fzfcmd,
      nth = "2.."
    })
  end
})

-- CTRL-D + ALT-V = Выбор страниц с поиском по id, пространству, заголовку и тэгам одновременно
map('n','<C-d><A-v>', '',  {
  desc = "",
  noremap = true, silent = true,
  callback = function()
    require("nvim-confluence").pages.load({
      fzf = fzfcmd,
      nth = nil
    })
  end
})

-- CTRL-D + С = Создать страницу из текущего буфера, выбрав родительскую из списка
map('n','<C-d>c', '',  {
  desc = "",
  noremap = true, silent = true,
  callback = function()
    require("nvim-confluence").pages.create({
      fzf = fzfcmd
    })
  end
})

-- CTRL-D + U = Заменить выбранную страницу содержимым текущего буфера
map('n','<C-d>u', '',  {
  desc = "",
  noremap = true, silent = true,
  callback = function()
    require("nvim-confluence").pages.update({
      fzf = fzfcmd
    })
  end
})

-- CTRL-D + M = Опубликовать содержимое текущего буфера в формате Markdown в качестве комментария к выбранным страницам
map('n','<C-d>m', '',  {
  desc = "",
  noremap = true, silent = true,
  callback = function()
    require("nvim-confluence").comments.comment({
      fzf = fzfcmd
    })
  end
})

-- CTRL-D + L = Открыть селектор удаления страниц с выбором по id, пространству, заголовку и тэгам одновременно
map('n','<C-d>l', '',  {
  desc = "",
  noremap = true, silent = true,
  callback = function()
    require("nvim-confluence").pages.delete({
      fzf = fzfcmd,
      nth = "1"
    })
  end
})

-- CTRL-D + SHIFT-L = Открыть селектор удаления страниц с выбором по тэгам
map('n','<C-d>L', '',  {
  desc = "",
  noremap = true, silent = true,
  callback = function()
    require("nvim-confluence").pages.delete({
      fzf = fzfcmd,
      nth = "2.."
    })
  end
})
```

## Доступные команды Neovim

* `:ConfluenceUpdate`
* `:ConfluenceInstallPandocFilter`

Также доступны несколько других команд, пока не описаны.

## Порядок работы

Чтобы локальная база данных SQLite, выполняющая роль кэша для списка страниц,
соответствовала содержимому сервера Confluence, выполните команду
`:ConfluenceUpdate`.

Плагин подключится к серверу, указанному в `CONFLUENCE_HOST` с токеном из
`CONFLUENCE_TOKEN` и запросит у него все страницы из пространств, указанных
в `CONFLUENCE_SPACES`. О каждом успешно выполненном запросе появляется
уведомление `nvim-notify` с кодом 200. Запрашивается 500 элементов на страницу
выдачи, что является максимально допустимым значением для Confluence.

Выгрузка страниц будет разобрана, существующие таблицы БД SQLite будут созданы
заново: будут созданы таблицы страниц, тэгов, связей страниц с тэгами,
и кэширующая таблица для показа списка страниц в `fzf`.

Необходимость в кэширующей таблице для `fzf` обусловлена тем, что выполнять
при каждом вызове `fzf` поиск по БД с подгрузкой соответствующих тэгов для
страницы — медленно даже для 2000 страниц. Проще сразу создать нужные строки
(в которых к заголовку страницы будут добавлены тэги страницы) и загружать уже
её.

После создания БД (появится всплывающее сообщение `nvim-notify` «SQLite backend
has been updated»)

### Загрузка страниц

Если база страниц Confluence создана, можно вызвать загрузчик страниц,
и выбрать одну или несколько страниц для загрузки:

* с трансформацией через `pandoc` в нужный формат (`ENTER`); сейчас это
  Asciidoc. Страница трансформируется на стороне Confluence в чистый валидный
  HTML, выполняются вставки (include), и HTML возвращается сервером. Именно этот
  HTML трансформируется в Asciidoc;

* в том виде, в котором она хранится в Confluence (`CTRL-Y`),

* в виде отформатированного XHTML (посредством `xmlreader`) (`CTRL-T`), при
  этом выгружается страница в исходном виде, с XML-вставками Confluence;

Также можно открыть выбранные страницы Confluence в браузере (`ALT-O`, open) или
вставить в текущий буфер ссылки на выбранные страницы в формате Markdown
(`CTRL-P`, paste). Последнее полезно при написании комментариев либо к самим
страницам Confluence, либо в Youtrack.

Доступны операции переименования страниц (`ALT-R`, rename) и перемещения
страниц (`ALT-M`, move). Для перемещения страниц открывается дополнительное
окно, которое **нужно сделать активным на ввод, перейдя в режим вставки** (`i`,
`I`, `a`, `A`).

### Удаление страниц

В окне выбора страниц доступны следующие операции:

* `CTRL-L` — удаление только выбранных страниц;
* `CTRL-W` — удаление выбранных страниц вместе с их дочерними страницами.

### Тэгирование страниц

Окно выбора тэгов предоставляет возможность выбора тэгов, которые будут
добавлены или удалены со страниц (на следующем экране).

Для случая, если нужного тэга в списке нет (вы хотите создать новый тэг,
отсутствующий в Confluence), необходимо нажать `CTRL-B`. В этом случае
содержимое поля ввода FZF (фильтра) будет записано в базу данных, и появится
при следующем открытии окна выбора тэгов.

Если такой новый тэг не будет добавлен в Confluence, то при следующем
обновлении БД (`:ConfluenceUpdate`) он будет удалён, потому что база данных
всегда заменяется содержимым из Confluence.

### Скриптование

TODO
