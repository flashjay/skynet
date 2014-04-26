local skynet = require "skynet"
local socket = require "socket"
local jsonpack = require "jsonpack"
local netpack = require "netpack"
local md5 = require "md5"

local h = skynet.getenv "h" -- hash token
local M = {}

M.ERROR = {
    INVALID_ARGS    = {0, "非法参数"},
    INVALID_COMMAND = {1, "非法指令"},
    DUPLICATE_LOGIN = {2, "重复登录"},
    DUPLICATE_AUTH  = {3, "重复认证"},
    PARAMS_ERROR    = {4, "参数错误"},
    NOT_AUTH        = {5, "未认证"},
    INVALID_ROOMID  = {6, "非法roomid"},
    MULTI_USER      = {7, "禁止同时登录多个账号"},--可以同时进入多个房间
    ROOM_ERROR      = {8, "发送失败"},
}

local function _send(fd, session, v)
    if h then
        v[3] = string.sub(md5.sumhexa(jsonpack.response(session,v)), -6)
    else
        v[3] = string.sub(tostring(os.time()), -6)
    end
	socket.write(fd, netpack.pack(jsonpack.response(session,v)))
end

function M.error(fd, co)
    _send(fd, 0, {"ERROR", { code= co[1], msg= co[2] }})
end

function M.room(fd, session, msg)
    _send(fd, session, {"ROOM", msg})
end

function M.auth(fd, session, msg)
    _send(fd, session, {"AUTH", msg})
end

function M.heartbeat(fd, session)
    _send(fd, session, {"HB", {ts=os.time()}})
end

return M
