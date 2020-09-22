-- enduser_setup,file,gpio,mdns,net,node,tmr,uart,wifi,wps,ws2812

--init.lua
firmwareVersion = "1.0.0"
rRgbLedPin = 5
gRgbLedPin = 1
bRgbLedPin = 2
greenLedPin = 7
touchPin = 8
relayPin = 6

gpio.mode(greenLedPin, gpio.OUTPUT)
gpio.mode(touchPin, gpio.INT)
gpio.mode(relayPin, gpio.OUTPUT)

ws2812.init(ws2812.MODE_SINGLE) -- pin data D4
-- turn off leds
ws2812.write(string.char(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0))

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

local tsp = 0;

-- define a callback function
function touch(level, stamp)
  -- print('touch '..gpio.read(touchPin))
  print('level:', level)       -- print level of on pin
  print('stamp:', stamp) -- print timestamp while interrupt occur

  if (level == 1) then
    tsp = stamp
  else
    local diff = stamp - tsp

    if (diff >= 5000000) then
      print('diff:', diff) -- print timestamp while interrupt occur
      print("Resetting device...")
      wifi.sta.clearconfig()
      fileSystem.clearSettings("config.net")

      tmr.delay(1000)
      node.restart()
    end
  end
end

-- register a touch event
-- ttp223 touch sersor react on "both" events
gpio.trig(touchPin, "both", touch)

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
    if cnt == 30 then
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
