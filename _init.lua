-- adc enduser_setup file gpio http mdns mqtt net node pwm sjson tmr uart wifi wps
-- math.floor((adc.read(0) / 1024) * 100)

--init.lua
rRgbLedPin = 5
gRgbLedPin = 1
bRgbLedPin = 2
greenLedPin = 7
resetPin = 6
buttonPin = 4

gpio.mode(greenLedPin, gpio.OUTPUT)
gpio.mode(buttonPin, gpio.INT, gpio.PULLUP)
gpio.mode(resetPin, gpio.INT, gpio.PULLUP)

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
function resetCb()
  -- print("Resetting device...")
  wifi.sta.clearconfig()
  fileSystem.clearSettings("config.net")
  fileSystem.clearSettings("detach.conf")
  fileSystem.clearSettings("lock.conf")

  tmr.delay(1000)
  node.restart()
end

-- register a reset event
-- that means, what's registered here is executed upon reset event "up"
gpio.trig(resetPin, "up", resetCb)

-- print("Connecting to wifi...")

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
    -- print(cnt .. " attempt...") -- waiting for ip
    if cnt == 30 then
      connTick:stop()
      connTick:unregister()
      -- print("Entering wps setup...")
      print("_init wps: ", node.heap())
      dofile("wpssetup.lc")
    end
  else
    connTick:stop()
    connTick:unregister()

    print("_init mqtt: ", node.heap())
    dofile("mqttsub.lc")

  end
end)
