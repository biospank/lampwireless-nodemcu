-- enduser_setup,file,gpio,mdns,net,node,softuart,tmr,uart,wifi,wps,ws2812

--init.lua
firmwareVersion = "1.0.0"
greenLedPin = 7

gpio.mode(greenLedPin, gpio.OUTPUT)

-- ws2812 library
ws2812.init(ws2812.MODE_SINGLE) -- pin data D4
-- turn off leds
ws2812.write(string.char(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0))

-- Create new software UART with baudrate of 2400, D2 as Tx pin and D3 as Rx pin
s = softuart.setup(2400, 2, 3)
-- Set callback to run when 10 characters show up in the buffer
s:on("data", "\r", function(data)
  if string.match(data, "doorbell") == "doorbell" then
    print("doorbell")
  elseif string.match(data, "intercom") == "intercom" then
    print("intercom")
  elseif string.match(data, "alarm") == "alarm" then
    print("alarm")
  elseif string.match(data, "sos") == "sos" then
    print("sos")
  else
    print(data)
  end
end)

wifi.setmode(wifi.STATION)

fileSystem = dofile("fs.lc")
local netConf = fileSystem.loadSettings("config.net")

if (netConf ~= nil) then
  -- for k, v in pairs(netConf) do
  --   print(k .. "=" .. v)
  -- end
  wifi.sta.config({ssid = netConf.ssid, pwd = netConf.pwd})
else
  -- print("no netConf available")
end

-- wifi.sta.connect()

-- define a callback function
function buttonCb()
  -- print("Resetting device...")
  wifi.sta.clearconfig()
  fileSystem.clearSettings("config.net")

  tmr.delay(1000)
  node.restart()
end

print("Connecting to wifi...")

local connTick = tmr.create()
local ledState = gpio.LOW

-- print("_init start: ", node.heap())

bootLedTick = tmr.create()

bootLedTick:alarm(500, tmr.ALARM_AUTO, function()
  if ledState == gpio.LOW then
    ledState = gpio.HIGH
  else
    ledState = gpio.LOW
  end

  gpio.write(greenLedPin, ledState)
end)

local cnt = 0

connTick:alarm(500, tmr.ALARM_AUTO, function()
  if wifi.sta.getip() == nil then
    cnt = cnt + 1
    print(cnt .. " attempt...") -- waiting for ip
    if cnt == 20 then
      connTick:stop()
      print("Entering wps setup...")
      dofile("wpssetup.lc")
    end
  else
    connTick:stop()
    bootLedTick:stop()
    gpio.write(greenLedPin, gpio.HIGH)
    print("Connected to wifi as: " .. wifi.sta.getip())
    dofile("mdnservice.lc") -- expose mdn service
    dofile("httpserver.lc") -- start http server
  end
end)
