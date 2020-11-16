---
--  Lua SCGI Request module.
--
--  @module     scgi.request
--  @author     t-kenji <protect.2501@gmail.com>
--  @license    MIT
--  @copyright  2020-2021 t-kenji

local util = require('scgi.util')

local _M = {}

local parse_body = function (environ)
    local input_maker = function (input)
        local obj = {}
        local read = input.receive or input.read

        function obj:read(number)
            return read(input, number)
        end
        return obj
    end

    local length = tonumber(environ.CONTENT_LENGTH) or 0
    local content_type = environ.CONTENT_TYPE or ''
    local body = input_maker(environ['scgi.input']):read(length) or ''
    if string.find(content_type, 'application/x-www-form-urlencoded', 1, true) then
        return util.parse_qs(body), ''
    else
        return {}, body
    end
end

local parse_cookie = function (str)
    str = str or ''

    local cookie = {}
    for k, v in str:gmatch('([%w_-]*)=([%w_-]*);*') do
        cookie[k] = v
    end
    return cookie
end

function _M.parse(environ)
    local query = util.parse_qs(environ.QUERY_STRING)
    local forms, body = parse_body(environ)
    local cookie = parse_cookie(environ.HTTP_COOKIE)

    return {
        query = query,
        forms = forms,
        body = body,
        cookie = cookie,
    }
end

return _M
