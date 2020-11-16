# SCGI module for Lua

## Features

- Implemented in pure Lua: works with 5.4

## Usage

The `scgi.lua` file should be download into an `package.path` directory and required by it:

```lua
local scgi = require('scgi')
```

The module provides the following functions:

### scgi.run(application, sock)

Reads a stream from the `sock` and runs an `application`.

Such like a wsgi in python implementation in python.

```lua
function application(environ, start_response)
end

scgi.run(application, sock)
```

## License

This module is free software; you can redistribute it and/or modify it under
the terms of the MIT license. See [LICENSE](LICENSE) for details.

