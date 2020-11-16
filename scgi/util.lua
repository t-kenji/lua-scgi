---
--  Lua SCGI Utility module.
--
--  @module     scgi.util
--  @author     t-kenji <protect.2501@gmail.com>
--  @license    MIT
--  @copyright  2020-2021 t-kenji

local _M = {}

function _M.quote(str)
    str = string.gsub(str, '\n', '\r\n')
    str = string.gsub(str, '([^%w])', function (c)
        return string.format('%%%02X', string.byte(c))
    end)
    str = string.gsub(str, ' ', '+')
    return str
end

function _M.unquote(str)
    str = string.gsub(str, '+', ' ')
    str = string.gsub(str, '%%(%x%x)', function (h) return string.char(tonumber(h, 16)) end)
    str = string.gsub(str, '\r\n', '\n')
    return str
end

function _M.parse_qs(qs)
    local t = {}
    for k, v in string.gmatch(qs, '([^&=]+)=([^&=]*)&?') do
        t[_M.unquote(k)] = _M.unquote(v)
    end
    return t
end

return _M
