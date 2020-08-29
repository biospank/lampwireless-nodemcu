-- fs.lua

local fs = {}
local _SETTINGS = {}

function fs.loadSettings(fileName)
  if file.open(fileName, "r") then
    repeat
      line = file.readline()
      if (line ~= nil) then
        k, v = string.match(string.gsub(line,"\n",""), "(%w+)=(.+)")
        -- -- print(k, v)
        _SETTINGS[k] = v
      end
    until not line

    file.close()

    return _SETTINGS
  else
    return nil
  end
end

function fs.dumpSettings(fileName, settings)
  if file.open(fileName, "w") then
    for k, v in pairs(settings) do
      file.writeline(k .. "=" .. tostring(v))
    end

    file.close()
  end
end

function fs.clearSettings(fileName)
  file.remove(fileName)
end

return fs
