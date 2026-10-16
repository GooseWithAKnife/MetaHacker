MH = MH or {}
MH.Log = {}

local function emit(level, source, subchannel, content)
    if metalog and metalog[level] then
        metalog[level](source, subchannel, content)
        return
    end
    print("[Metahacker/" .. level .. "] " .. source .. " / " .. subchannel .. " / " .. tostring(content))
end

function MH.Log.info(source, subchannel, content) emit("info", source, subchannel, content) end
function MH.Log.warn(source, subchannel, content) emit("warn", source, subchannel, content) end
function MH.Log.error(source, subchannel, content) emit("error", source, subchannel, content) end
