local skynet = require "skynet"
local mongo = require "mongo"
local json = require "cjson"
local config = require "config"

local mongo_conf = skynet.getenv "mongo"
local _cfg = config(mongo_conf)["main"]

local config = {port= _cfg.port, host= _cfg.host, db=_cfg.db}

local db

local command = {}

function command.NEW(userid, sid)
    local col = db:getCollection(_cfg.col)
    col:insert({_id= userid, sid= sid})
end

function command.AUTH(userid, sid) -- sid = token
    -- print(">> mongo auth ->", userid, sid)
    local col = db:getCollection(_cfg.col)
    local row = col:findOne({_id=userid})
    if not row then
        return 0
    end
    if not row["sid"] then
        return 0
    end
    if sid ~= row["sid"] then
        return 0
    end
    return 1
end

skynet.start(function()
    local mc = mongo.client(config)
    db = mc:getDB(config.db)

    command.NEW(1, "TOKEN_STRING")
	skynet.dispatch("lua", function(_,_, cmd, ...)
		local f = command[cmd]
		skynet.ret(skynet.pack(f(...)))
	end)
	skynet.register "MONGO_PROXY"
end)
