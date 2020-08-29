-- enduser_setup,file,gpio,mdns,net,node,tmr,uart,wifi,pwm,wps

--init.lua
firmwareVersion = "1.0.0"
rRgbLedPin = 5
gRgbLedPin = 1
bRgbLedPin = 2
greenLedPin = 7
buttonPin = 3
relayPin = 6

gpio.mode(greenLedPin, gpio.OUTPUT)
gpio.mode(buttonPin, gpio.INT, gpio.PULLUP)
gpio.mode(relayPin, gpio.OUTPUT)
pwm.setup(rRgbLedPin, 1000, 1023) -- we are using 1000Hz
pwm.setup(gRgbLedPin, 1000, 1023) -- we are using 1000Hz
pwm.setup(bRgbLedPin, 1000, 1023) -- we are using 1000Hz
pwm.start(rRgbLedPin)
pwm.start(gRgbLedPin)
pwm.start(bRgbLedPin)

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

-- register a button event
-- that means, what's registered here is executed upon button event "up"
gpio.trig(buttonPin, "up", buttonCb)

print("Connecting to wifi...")

local connTick = tmr.create()
local ledState = gpio.LOW

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
