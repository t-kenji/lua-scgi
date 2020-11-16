---
--  Lua SCGI module.
--
--  @module     scgi
--  @author     t-kenji <protect.2501@gmail.com>
--  @license    MIT
--  @copyright  2020-2021 t-kenji

local _M = {
    _VERSION = "SCGI 0.1.0",
}

local validator = {}

validator.header = function (headers)
    if headers[1] ~= 'CONTENT_LENGTH' then
        error('SCGI spec mandates CONTENT_LENGTH be the first header')
    end

    if headers.CONTENT_LENGTH == '' then
        error('SCGI requires CONTENT_LENGTH have a value, even if "0"')
    end

    if headers.SCGI ~= '1' then
        error('request from webserver must be "SCGI" header with value of "1"')
    end

    if not tonumber(headers.CONTENT_LENGTH, 10) then
        error('CONTENT_LENGTH is not a decimal number')
    end
end

function _M.run(application, stdin, stdout, stderr)
    stdin = stdin or io.stdin
    stdout = stdout or io.stdout
    stderr = stderr or io.stderr

    local function readlen()
        local frags = {}
        while true do
            local c, err = stdin:receive(1)
            if err ~= nil and err ~= 'timeout' then
                error(err)
            end

            if c == nil or c == ':' then
                break
            end

            if c ~= nil then
                table.insert(frags, c)
            end
        end
        return tonumber(table.concat(frags))
    end

    local len = readlen()
    if not len then
        error('netstring size not found in SCGI request')
    end

    local str = stdin:receive(len)
    local headers = {}
    for k, v in str:gmatch('(%Z+)%z(%Z*)%z') do
        if headers[k] then
            error('duplicate SCGI header encountered ' .. k)
        end

        table.insert(headers, k)
        headers[k] = v
    end

    validator.header(headers)

    -- skip ','
    stdin:receive(1)

    local environ = {}
    for k, v in pairs(headers) do
        if type(k) ~= 'number' then
            environ[k] = v
        end
    end
    environ['scgi.input'] = stdin
    environ['scgi.errors'] = stderr

    local headers_set = {}
    local headers_sent = {}

    local function write(data)
        if #headers_set == 0 then
            error('write() before start_response()')
        elseif #headers_sent == 0 then
            headers_sent = headers_set
            local status, response_headers = table.unpack(headers_set)
            stdout:send('Status: ' .. status .. '\r\n')
            for k, v in pairs(response_headers) do
                if type(v) == 'string' then
                    stdout:send(k .. ': ' .. v .. '\r\n')
                elseif type(v) == 'table' then
                    for i = 1, #v do
                        stdout:send(k .. ': ' .. v[i] .. '\r\n')
                    end
                end
            end
            stdout:send('\r\n')
        end

        if type(data) == 'string' then
            stdout:send(data .. '\r\n')
        elseif type(data) == 'table' then
            for _, v in ipairs(data) do
                stdout:send(v .. '\r\n')
            end
        elseif type(data) == 'function' then
            for v in data do
                stdout:send(v .. '\r\n')
            end
        end
    end

    local function start_response(status, response_headers)
        if #headers_set > 0 then
            error('headers already set')
        end

        headers_set = {status, response_headers}

        return write
    end

    local function execute()
        return coroutine.wrap(function ()
            coroutine.yield(application(environ, start_response))
        end)
    end

    local ok, err = pcall(function ()
        for result in execute() do
            write(result)
        end
    end)
    if not ok then
        error(err)
    end
end

function _M.errors(message, stdin, stdout, stderr)
    stdin = stdin or io.stdin
    stdout = stdout or io.stdout
    stderr = stderr or io.stderr

    stdout:send('Content-Type: text/plain\r\nStatus: 500 Internal Server Error\r\n\r\n' .. message)
end

return _M
