local pirTick = tmr.create()

local sendRequest = function()
  if ((clientConf.active or "true") == "true") then
    print("Sending http request...")
    print("http://"..lampServerIp..":"..lampServerPort.."/notify?mode="..(clientConf.mode or "alarm").."&client="..(clientConf.client or "pir").."&delay="..(clientConf.delay or "5000").."&alert="..(clientConf.alert or "false"))

    http.get("http://"..lampServerIp..":"..lampServerPort.."/notify?mode="..(clientConf.mode or "alarm").."&client="..(clientConf.client or "pir").."&delay="..(clientConf.delay or "5000").."&alert="..(clientConf.alert or "false"), nil, function(code, data)
      if (code < 0) then
        print("HTTP request failed")
      else
        print(code, data)
        print("http request sent!")
      end
    end)
  end
end

local bouncingTime = 0

pirTick:alarm(500, tmr.ALARM_AUTO, function()
  if gpio.read(PIRpin) == 1 then
    -- print("move detected!")
    -- print(bouncingTime)
    if bouncingTime == 0 then
      bouncingTime = bouncingTime + 1
      sendRequest()
    end
  else
    -- print("no movement...")
    -- print(bouncingTime)
    if bouncingTime > 0 then
      bouncingTime = bouncingTime + 1
    end

    if bouncingTime > 5 then
      bouncingTime = 0
    end
  end
end)
