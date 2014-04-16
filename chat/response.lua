local socket = require "socket"
local jsonpack = require "jsonpack"
local netpack = require "netpack"
local md5 = require "md5"

local M = {} 

M.ERROR = {
    INVALID_ARGS    = {0, "非法参数"},
    INVALID_COMMAND = {1, "非法指令"},
    DUPLICATE_LOGIN = {2, "重复登录"},
    DUPLICATE_AUTH  = {3, "重复认证"},
    PARAMS_ERROR    = {4, "参数错误"},
    NOT_AUTH        = {5, "未认证"},
}

local function _msg(fd, session, v)
    local h = tostring(os.time()) --hash
    v[3] = h
	socket.write(fd, netpack.pack(jsonpack.response(session,v)))
end

function M.error(fd, co)
    _msg(fd, 0, {"ERROR", { code= co[1], msg= co[2] }})
end

function M.room(fd, session, msg)
    _msg(fd, session, {"ROOM", msg})
end

function M.auth(fd, session, msg)
    _msg(fd, session, {"AUTH", msg})
end

return M
