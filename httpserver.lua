redLedTick = tmr.create()

function turnAlertOn()
  local ledState = gpio.LOW

  running, mode = redLedTick:state()

  if not running then
    redLedTick:alarm(500, tmr.ALARM_AUTO, function()
      if ledState == gpio.LOW then
        ledState = gpio.HIGH
      else
        ledState = gpio.LOW
      end

      gpio.write(redLedPin, ledState)
    end)
  end
end

function turnAlertOff()
  running, mode = redLedTick:state()

  if running then
    redLedTick:stop()
    gpio.write(redLedPin, gpio.LOW)
  end
end

function turnRelayOn(vars, alert)
  print("Turning on gpio 2..")

  local params = collectQueryStringParams(vars)

  gpio.write(relayPin, gpio.HIGH)

  tmr.create():alarm(tonumber((params.delay) or 5000), tmr.ALARM_SINGLE, function()
    print("Turning off gpio 2..")
    gpio.write(relayPin, gpio.LOW)

    print("alert " .. tostring(alert))

    if alert then
      turnAlertOn()
    end
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

    if url == "favicon.ico" then
      conn:send("HTTP/1.1 404 file not found")
      return
    end

    if url == "test" then
      turnRelayOn(vars, false)
    end

    if url == "notify" then
      turnRelayOn(vars, true)
    end

    if url == "alertoff" then
      turnAlertOff()
    end

    conn:send("HTTP/1.1 200 OK\r\n\r\n")
  end)

  conn:on("sent", function(conn)
    -- conn:send("<!DOCTYPE html><html>ok</html>")
    conn:send("ok")
    conn:close()
    collectgarbage();
  end)
end)
