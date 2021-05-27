local ffi = require "ffi"
local os_name = ffi.os

local ngx_prefix = ngx.config.prefix()
local ok =
    os.execute(
    string.format(
        "cd %s/dv/3rd/socket && ln -sf core_%s.so core.so",
        ngx_prefix,
        os_name,
        ngx_prefix
    )
)

if not ok then
    ngx.log(ngx.ERR, "fail to create link for socket.so")
end
assert(ok == true)
