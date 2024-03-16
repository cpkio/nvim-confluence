local https = require"ssl.https"
local ltn12 = require"ltn12"

local api = {}

local function request_builder()
  local list = os.getenv('CONFLUENCE_SPACES')
  local spaces = vim.fn.split(list,';')
  local _a = {}
  for _,space in pairs(spaces) do
    table.insert(_a, '(space=' .. space .. ' and type=page)')
  end
  return vim.fn.join(_a, ' OR ')
end

function api.new()
  return setmetatable({}, { __index = api })
end

function api:get(endpoint)
  local response_body = {}

  local base_url = os.getenv("CONFLUENCE_HOST")
  local endpoint = endpoint or ("/rest/api/content/search?limit=500&expand=space,metadata.labels&cql=" .. require("socket.url").escape(request_builder()))
  local res, code, response_headers, status = https.request{
      url = base_url .. endpoint,
      method = "GET",
      headers = {
        ["Authorization"] = "Bearer " .. os.getenv("CONFLUENCE_TOKEN")
      },
      sink = ltn12.sink.table(response_body),
      maxredirects = false
  }

  vim.notify('GET code ' .. tostring(code) .. ', status ' .. tostring(status))
  if code == 200 then
    return vim.fn.json_decode(table.concat(response_body))
  else
    return nil
  end
end

function api:post(space, title, ancestor, page)
  local post_body = {
    type = "page",
    title = title,
    ancestors = { { id = ancestor } },
    space = { key = space},
    body = { storage = {
      representation = "storage",
      value = table.concat(page, "\n")
    } }
  }

  local response_body = {}

  local post_json = vim.json.encode(post_body)

  local base_url = os.getenv("CONFLUENCE_HOST")
  local endpoint = "/rest/api/content"

  local res, code, response_headers, status = https.request{
      url = base_url .. endpoint,
      method = "POST",
      headers = {
        ["Authorization"] = "Bearer " .. os.getenv("CONFLUENCE_TOKEN"),
        ["Content-Type"] = "application/json",
        ["Content-Length"] = #post_json
      },
      source = ltn12.source.string(post_json),
      sink = ltn12.sink.table(response_body),
  }

  vim.notify('POST code ' .. tostring(code) .. ', status ' .. tostring(status))

  if code ~=200 and type(response_body) == "table" then
    vim.notify(vim.inspect(
      vim.json.decode(table.concat(response_body))
    ), 5)
  else
    return vim.json.decode(table.concat(response_body))
  end

end

function api:put(space, title, page, id, version, message)
  local post_body = {
    type = "page",
    title = title,
    space = { key = space},
    id = id,
    version = { number = version, message = message},
    body = { storage = {
      representation = "storage",
      value = table.concat(page, "\n")
    } }
  }

  local response_body = {}

  local post_json = vim.json.encode(post_body)

  local base_url = os.getenv("CONFLUENCE_HOST")
  local endpoint = "/rest/api/content/" .. id

  local res, code, response_headers, status = https.request{
      url = base_url .. endpoint,
      method = "PUT",
      headers = {
        ["Authorization"] = "Bearer " .. os.getenv("CONFLUENCE_TOKEN"),
        ["Content-Type"] = "application/json",
        ["Content-Length"] = #post_json
      },
      source = ltn12.source.string(post_json),
      sink = ltn12.sink.table(response_body),
  }

  vim.notify('PUT code ' .. tostring(code) .. ', status ' .. tostring(status))

  if code ~=200 and type(response_body) == "table" then
    vim.notify(vim.inspect(
      vim.json.decode(table.concat(response_body))
    ), 5)
  else
    return vim.json.decode(table.concat(response_body))
  end

end

function api:post_comment(page, comment)
  local post_body = {
    type = "comment",
    container = { id = page, type = "page" },
    body = { storage = {
      representation = "storage",
      value = table.concat(comment, "\n")
    } }
  }

  local response_body = {}

  local post_json = vim.json.encode(post_body)

  local base_url = os.getenv("CONFLUENCE_HOST")
  local endpoint = "/rest/api/content"

  local res, code, response_headers, status = https.request{
      url = base_url .. endpoint,
      method = "POST",
      headers = {
        ["Authorization"] = "Bearer " .. os.getenv("CONFLUENCE_TOKEN"),
        ["Content-Type"] = "application/json",
        ["Content-Length"] = #post_json
      },
      source = ltn12.source.string(post_json),
      sink = ltn12.sink.table(response_body),
  }

  vim.notify('POST code ' .. tostring(code) .. ', status ' .. tostring(status))

  if code ~=200 and type(response_body) == "table" then
    vim.notify(vim.inspect(
      vim.json.decode(table.concat(response_body))
    ), 5)
  else
    return nil
  end
end

function api:delete(page)
  local response_body = {}
  local base_url = os.getenv("CONFLUENCE_HOST")
  local endpoint = "/rest/api/content/" .. page

  local res, code, response_headers, status = https.request{
      url = base_url .. endpoint,
      method = "DELETE",
      headers = {
        ["Authorization"] = "Bearer " .. os.getenv("CONFLUENCE_TOKEN"),
      },
      sink = ltn12.sink.table(response_body),
  }

  if code ~=204 and type(response_body) == "table" then
    vim.notify(vim.inspect(
      vim.json.decode(table.concat(response_body))
    ), 5)
  else
    return nil
  end
end

function api:move(id, newparentid, title, version, parenttitle)
  local post_body = {
    type = "page",
    title = title,
    version = { number = version, message = 'Перемещение страницы в дочернюю для "' .. parenttitle ..  '"'},
    ancestors = { { id = newparentid } },
  }

  local response_body = {}

  local post_json = vim.json.encode(post_body)

  local base_url = os.getenv("CONFLUENCE_HOST")
  local endpoint = "/rest/api/content/" .. id

  local res, code, response_headers, status = https.request{
      url = base_url .. endpoint,
      method = "PUT",
      headers = {
        ["Authorization"] = "Bearer " .. os.getenv("CONFLUENCE_TOKEN"),
        ["Content-Type"] = "application/json",
        ["Content-Length"] = #post_json
      },
      source = ltn12.source.string(post_json),
      sink = ltn12.sink.table(response_body),
  }

  vim.notify('PUT code ' .. tostring(code) .. ', status ' .. tostring(status))

  if code ~=200 and type(response_body) == "table" then
    vim.notify(vim.inspect(
      vim.json.decode(table.concat(response_body))
    ), 5)
  else
    return nil
  end

end

function api:rename(id, title, newtitle, version)
  local post_body = {
    type = "page",
    title = newtitle,
    version = { number = version, message = 'Страница переименована из "' .. title .. '" в "' .. newtitle .. '"' },
  }

  local response_body = {}

  local post_json = vim.json.encode(post_body)

  local base_url = os.getenv("CONFLUENCE_HOST")
  local endpoint = "/rest/api/content/" .. id

  local res, code, response_headers, status = https.request{
      url = base_url .. endpoint,
      method = "PUT",
      headers = {
        ["Authorization"] = "Bearer " .. os.getenv("CONFLUENCE_TOKEN"),
        ["Content-Type"] = "application/json",
        ["Content-Length"] = #post_json
      },
      source = ltn12.source.string(post_json),
      sink = ltn12.sink.table(response_body),
  }

  vim.notify('PUT code ' .. tostring(code) .. ', status ' .. tostring(status))

  if code ~=200 and type(response_body) == "table" then
    vim.notify(vim.inspect(
      vim.json.decode(table.concat(response_body))
    ), 5)
  else
    return nil
  end

end

function api:delete_tree(page)
  local response_body = {}
  local base_url = os.getenv("CONFLUENCE_HOST")
  local endpoint = "/rest/api/content/search?cql=ancestor=" .. page

  local res, code, response_headers, status = https.request{
      url = base_url .. endpoint,
      method = "GET",
      headers = {
        ["Authorization"] = "Bearer " .. os.getenv("CONFLUENCE_TOKEN"),
      },
      sink = ltn12.sink.table(response_body),
  }

  if code == 200 then
    for _,v in pairs(vim.json.decode(table.concat(response_body)).results) do
      api:delete(v.id)
    end
    api:delete(page)
  else
    vim.notify(vim.inspect(
      vim.json.decode(table.concat(response_body))
    ), 5)
  end
end

function api:convert(page)
  local post_body = {
    representation = "storage",
    value = page
  }

  local response_body = {}

  local post_json = vim.json.encode(post_body)

  local base_url = os.getenv("CONFLUENCE_HOST")
  local endpoint = "/rest/api/contentbody/convert/view"

  local res, code, response_headers, status = https.request{
      url = base_url .. endpoint,
      method = "POST",
      headers = {
        ["Authorization"] = "Bearer " .. os.getenv("CONFLUENCE_TOKEN"),
        ["Content-Type"] = "application/json",
        ["Content-Length"] = #post_json
      },
      source = ltn12.source.string(post_json),
      sink = ltn12.sink.table(response_body),
  }
  vim.notify('POST code ' .. tostring(code) .. ', status ' .. tostring(status))

  return vim.json.decode(table.concat(response_body))
end

function api:tag(page, title, tags)
  local post_body = {}
  for _, tag in pairs(tags) do
    table.insert(post_body, { prefix = "global", name = tag })
  end

  local response_body = {}

  local post_json = vim.json.encode(post_body)

  local base_url = os.getenv("CONFLUENCE_HOST")
  local endpoint = "/rest/api/content/" .. page .. "/label"

  local res, code, response_headers, status = https.request{
      url = base_url .. endpoint,
      method = "POST",
      headers = {
        ["Authorization"] = "Bearer " .. os.getenv("CONFLUENCE_TOKEN"),
        ["Content-Type"] = "application/json",
        ["Content-Length"] = #post_json
      },
      source = ltn12.source.string(post_json),
      sink = ltn12.sink.table(response_body),
  }
  vim.notify('POST code ' .. tostring(code) .. ', status ' .. tostring(status))

  if code ~=200 and type(response_body) == "table" then
    vim.notify(vim.inspect(
      vim.json.decode(table.concat(response_body))
    ), 5)
  else
    vim.notify("Статья «" .. title  .. "» помечена тэгами [" .. table.concat(tags, ',') ..']')
    return nil
  end
end

function api:tag_remove(page, title, tag)
  local response_body = {}
  local base_url = os.getenv("CONFLUENCE_HOST")
  local endpoint = "/rest/api/content/" .. page .. "/label?name=" .. tag

  local res, code, response_headers, status = https.request{
      url = base_url .. endpoint,
      method = "DELETE",
      headers = {
        ["Authorization"] = "Bearer " .. os.getenv("CONFLUENCE_TOKEN"),
      },
      sink = ltn12.sink.table(response_body),
  }
  vim.notify('Response code ' .. tostring(code) .. ', status ' .. tostring(status))

  if code ~=204 and type(response_body) == "table" then
    vim.notify(vim.inspect(
      vim.json.decode(table.concat(response_body))
    ), 3)
  else
    vim.notify("Тэг «" .. tag .. "» удален со страницы «" .. title  .. "»")
    return nil
  end
end

return api
