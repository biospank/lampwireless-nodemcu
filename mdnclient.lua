local mc = dofile("mdns.lua")

--constants
local service_to_query = '_lampwireless._tcp' --service pattern to search
local query_timeout = 3 -- seconds
local query_repeat_interval = 6 -- seconds
local foundBroker = false
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
    print("Got Query results")
    lampServerIp, lampServerPort = mc.extractIpAndPortFromResults(res, 1)

    print(lampServerIp)
    print(lampServerPort)

    if lampServerIp and lampServerPort then
      foundBroker = true
      print('Lamp server '..lampServerIp..":"..lampServerPort)
      bootLedTick:stop()
      gpio.write(greenLedPin, gpio.HIGH)
      activateMdnLed(false)
      dofile("pir.lua")
    else
      print('Browse attempt returned no matching results')
    end
  else
    print('no device found in local network. please ensure that they are running and advertising on mdns')
  end
end

activateMdnLed(true)

mdnTick:alarm(query_repeat_interval * 1000, tmr.ALARM_AUTO, function()
  if foundBroker == true then
    mdnTick:stop()
  else
    print('Retry mdns discovery...')
    mc.query(service_to_query, query_timeout, wifi.sta.getip(), result_handler)
  end
end)
