rgbLedTick = tmr.create()
relayTick = tmr.create()
red, green, blue = nil

function turnAlertOn(params, temporary)
  local ledState = gpio.LOW
  local count = 0
  local running, _mode = rgbLedTick:state()

  red = tonumber(params.r)
  green = tonumber(params.g)
  blue = tonumber(params.b)

  print("Red: " .. (1023 - red))
  print("Green: " .. (1023 - green))
  print("Blue: " .. (1023 - blue))

  if not running then
    rgbLedTick:alarm(500, tmr.ALARM_AUTO, function()
      if temporary and count > 6 then
        turnAlertOff()
      end

      count = count + 1

      if ledState == gpio.LOW then
        ledState = gpio.HIGH
      else
        ledState = gpio.LOW
      end

      if ledState == gpio.HIGH then
        ws2812.write(string.char(green, red, blue, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0))
        -- pwm.setduty(rRgbLedPin, 1023 - red)
        -- pwm.setduty(gRgbLedPin, 1023 - green)
        -- pwm.setduty(bRgbLedPin, 1023 - blue)
      else
        ws2812.write(string.char(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0))
        -- pwm.setduty(rRgbLedPin, 1023)
        -- pwm.setduty(gRgbLedPin, 1023)
        -- pwm.setduty(bRgbLedPin, 1023)
      end
    end)
  else
    if temporary then
      turnAlertOff()
    end
  end
end

function turnAlertOff()
  local running, _mode = rgbLedTick:state()

  if running then
    rgbLedTick:stop()
    ws2812.write(string.char(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0))
    -- pwm.setduty(rRgbLedPin, 1023)
    -- pwm.setduty(gRgbLedPin, 1023)
    -- pwm.setduty(bRgbLedPin, 1023)
  end
end

local function flashLight(mode, ledState)
  if ledState == gpio.LOW then
    if mode == "alarm" then
      gpio.write(relayPin, gpio.HIGH)
      tmr.create():alarm(250, tmr.ALARM_SINGLE, function()
        gpio.write(relayPin, gpio.LOW)
      end)
    else
      -- ws2812.write(string.char(255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255))
      gpio.write(relayPin, gpio.HIGH)
    end
  else
    if mode == "alarm" then
      gpio.write(relayPin, gpio.HIGH)
      tmr.create():alarm(250, tmr.ALARM_SINGLE, function()
        gpio.write(relayPin, gpio.LOW)
      end)
    else
      -- ws2812.write(string.char(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0))
      gpio.write(relayPin, gpio.LOW)
    end
  end
end

function turnRelayOn(vars)
  print("Turning on gpio 2..")

  local params = collectQueryStringParams(vars)
  local times = tonumber((params.delay) or 5000) * 2 / 1000
  local ledState = gpio.LOW
  local running, mode = relayTick:state()
  local cnt = 0

  if not running then
    relayTick:alarm(500, tmr.ALARM_AUTO, function()
      if cnt < times then
        if ledState == gpio.LOW then
          ledState = gpio.HIGH
        else
          ledState = gpio.LOW
        end

        flashLight(params.mode, ledState)
      else
        print("Turning off gpio 2..")
        relayTick:stop()
        -- ws2812.write(string.char(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0))
        gpio.write(relayPin, gpio.LOW)

        print("alert " .. params.alert)

        if params.alert == "true" then
          turnAlertOn(params, false)
        end
      end

      cnt = cnt + 1
    end)
  end
end

function softReset()
  tmr.create():alarm(1000, tmr.ALARM_SINGLE, function()
    node.restart()
  end)
end

function collectQueryStringParams(vars)
  local _GET = {}
  if (vars ~= nil) then
    for k, v in string.gmatch(vars, "(%w+)=(%w+)&*") do
      _GET[k] = v
    end
  end

  return _GET
end

srv=net.createServer(net.TCP)
srv:listen(80, function(conn)
  local method=""
  local url=""
  local vars=""

  conn:on("receive", function(conn, payload)
    _, _, method, url, vars = string.find(payload, "([A-Z]+) /([^?]*)%??(.*) HTTP")

    if(url ~= nil) then
      print("url: " .. url)
    end

    if(vars ~= nil) then
      print("vars: " .. vars)
    end

    if url == "ping" then
    elseif url == "notify" then
      turnRelayOn(vars)
    elseif url == "testalert" then
      turnAlertOn(collectQueryStringParams(vars), true)
    elseif url == "alertoff" then
      turnAlertOff()
    elseif url == "reset" then
      softReset()
    elseif url == "firmware/version" then
      conn:send("HTTP/1.1 200 OK\r\n\r\n" .. firmwareVersion)
      return
    elseif url == "hardware/chipid" then
      conn:send("HTTP/1.1 200 OK\r\n\r\n" .. node.chipid())
      return
    else
      conn:send("HTTP/1.1 404 resource not found")
      return
    end

    conn:send("HTTP/1.1 200 OK\r\n\r\n")
  end)

  conn:on("sent", function(conn)
    -- conn:send("<!DOCTYPE html><html>ok</html>")
    -- conn:send("ok")
    conn:close()
    collectgarbage();
  end)
end)
