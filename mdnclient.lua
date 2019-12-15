local mc = dofile("mdns.lc")
print("mdnclient after mdns: ", node.heap())

--constants
local service_to_query = '_lampwireless._tcp' --service pattern to search
local query_timeout = 3 -- seconds
local query_repeat_interval = 6 -- seconds
local mdnTick = tmr.create()

local function activateMdnLed(active)
  if active then
    pwm.setduty(rRgbLedPin, 500)
    pwm.setduty(gRgbLedPin, 100)
    pwm.setduty(bRgbLedPin, 1023)
  else
    pwm.setduty(rRgbLedPin, 1023)
    pwm.setduty(gRgbLedPin, 1023)
    pwm.setduty(bRgbLedPin, 1023)
  end
end

-- handler to do some thing useful with mdns query results
local result_handler = function(err, res)
  if (res) then
    local lampServerIp, lampServerPort = mc.extractIpAndPortFromResults(res, 1)

    if lampServerIp and lampServerPort then
      -- print('Lamp server '..lampServerIp..":"..lampServerPort)
      mdnTick:stop()
      mdnTick:unregister()

      local settings = fileSystem.loadSettings("config.net")

      settings.serverip = lampServerIp
      settings.serverport = lampServerPort

      fileSystem.dumpSettings("config.net", settings)

      tmr.delay(1000)
      node.restart()
    else
      -- print('Browse attempt returned no matching results')
    end
  else
    -- print('no device found in local network. please ensure that they are running and advertising on mdns')
  end
end

activateMdnLed(true)

mdnTick:alarm(query_repeat_interval * 1000, tmr.ALARM_AUTO, function()
  -- print('Attempt mdns discovery...')
  mc.query(service_to_query, query_timeout, wifi.sta.getip(), result_handler)
end)
