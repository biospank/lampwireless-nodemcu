-- mqttsub.lua

local mqttConf = dofile("broker.lc")
local detachConf = fileSystem.loadSettings("detach.conf")
local lockConf = fileSystem.loadSettings("lock.conf")
local netConf = fileSystem.loadSettings("config.net")

local pirTick = tmr.create()
local isMqttAlive = false
local mqttBroker = nil
local deviceId = node.chipid()
local lampChipRequestAttempts = 1
local mqttConnectAttempts = 1
local deviceType = "pir"
local deviceConf = {}
local lampServerChipId = nil

local function mqttBrokerBaseTopic()
  return "lampwireless/" .. lampServerChipId .. "/device/" .. deviceId
end

local function mqttBrokerConfTopic()
  return mqttBrokerBaseTopic() .. "/conf"
end

local function mqttBrokerStatusTopic()
  return mqttBrokerBaseTopic() .. "/status"
end

local function mqttBrokerMessageTopic()
  return mqttBrokerBaseTopic() .. "/message"
end

local function offlineMessage()
  return {["id"] = deviceId, ["serverId"] = lampServerChipId, ["name"] = (deviceConf.name), ["type"] = deviceType, ["status"] = "offline", ["active"] = ((deviceConf.active ~= nil and deviceConf.active == true) or false), ["delay"] = (deviceConf.delay or "5000"), ["r"] = (deviceConf.r or "1000"), ["g"] = (deviceConf.g or "323"), ["b"] = (deviceConf.b or "0")}
end

local function onlineMessage()
  return {["id"] = deviceId, ["serverId"] = lampServerChipId, ["type"] = deviceType, ["status"] = "online", ["detached"] = ((detachConf ~= nil) or false), ["locked"] = (deviceConf.locked or false)}
end

local function alertMessage()
  return {["id"] = deviceId, ["serverId"] = lampServerChipId, ["type"] = deviceType, ["mode"] = (deviceConf.mode or "alarm"), ["type"] = (deviceConf.type or "pir"), ["delay"] = (deviceConf.delay or "5000"), ["alert"] = ((deviceConf.alert ~= nil and deviceConf.alert == true) or false), ["r"] = (deviceConf.r or "1000"), ["g"] = (deviceConf.g or "323"), ["b"] = (deviceConf.b or "0")}
end

local function setOnlineStatus()
  bootLedTick:stop()
  pwm.setduty(rRgbLedPin, 1023)
  pwm.setduty(gRgbLedPin, 1023)
  pwm.setduty(bRgbLedPin, 1023)
  gpio.write(greenLedPin, gpio.HIGH)
end

local function sendMessage()
  if (detachConf ~= nil) then
    if (deviceConf.active == true) then
      if isMqttAlive == true then
        -- print("Publishing mqtt message in detached mode...")
        mqttBroker:publish(mqttBrokerMessageTopic(), sjson.encode(alertMessage()), 2, 0)
      end
    end
  else
    if (deviceConf.active == true) then
      if isMqttAlive == true then
        print("Publishing mqtt message...")
        mqttBroker:publish(mqttBrokerMessageTopic(), sjson.encode(alertMessage()), 2, 0)
      end

      -- print("Sending http request...")

      local url = "http://"..netConf.serverip..":"..netConf.serverport.."/notify?mode="..(deviceConf.mode or "alarm").."&client="..(deviceConf.client or "pir").."&delay="..(deviceConf.delay or "5000").."&alert="..tostring(deviceConf.alert or false).."&r="..(deviceConf.r or "").."&g="..(deviceConf.g or "").."&b="..(deviceConf.b or "")

      -- print(url)

      print("mqttsub send message: ", node.heap())

      http.get(url, nil, function(code, data)
        if (code < 0) then
          print("mqttsub send message done: ", node.heap())
          -- print("HTTP request failed")
        else
          -- print(code, data)
          -- print("http request sent!")
        end
      end)
    end
  end
end


function listen(active)
  local bouncingTime = 0

  if active then
    pirTick:alarm(500, tmr.ALARM_AUTO, function()
      if gpio.read(PIRpin) == 1 then
        -- -- print("move detected!")
        -- -- print(bouncingTime)
        if bouncingTime == 0 then
          bouncingTime = bouncingTime + 1
          print("mqttsub listen catch: ", node.heap())
          sendMessage()
        end
      else
        -- -- print("no movement...")
        -- -- print(bouncingTime)
        if bouncingTime > 0 then
          bouncingTime = bouncingTime + 1
        end

        if bouncingTime > 5 then
          bouncingTime = 0
        end
      end
    end)
  else
    pirTick:stop()
  end

end

local function conn()
  -- print("Connecting to broker " .. mqttConf.brokerHost .. ":" .. tostring(mqttConf.brokerPort) .. " with usr: " .. mqttConf.brokerUsr .. " pwd: " .. mqttConf.brokerPwd .. "...")
  -- Set up last will testament
  mqttBroker:lwt(mqttBrokerStatusTopic(), sjson.encode(offlineMessage()), 1, 1)
  -- Connect to broker
  mqttBroker:connect(mqttConf.brokerHost, mqttConf.brokerPort, false, function(client)
    isMqttAlive = true
    mqttConnectAttempts = 1

    print("mqttsub conn success: ", node.heap())

    print("Subscribing to topic " .. mqttBrokerConfTopic() .. "...")
    -- subscribe topic with qos = 1
    client:subscribe(mqttBrokerConfTopic(), 1)

    tmr.create():alarm(3000, tmr.ALARM_SINGLE, function()
      print("Publishing online message to topic: " .. mqttBrokerStatusTopic() .. "...")
      client:publish(mqttBrokerStatusTopic(), sjson.encode(onlineMessage()), 1, 1)
    end)

    setOnlineStatus()
    listen(true)

  end,
  function(client, reason)
    -- print("Failed to connect: " .. reason)
    isMqttAlive = false
    listen(false)

    if (mqttConnectAttempts > 3) then
      -- print("Max connection attempts reached, giving up...")
      mqttConnectAttempts = 1
      setOnlineStatus()
      listen(true)
    else
      mqttConnectAttempts = mqttConnectAttempts + 1
      -- print("Attempt to connect in 3 sec...")
      print("mqttsub conn attempt: ", node.heap())
      tmr.delay(3000)
      conn()
    end
  end)
end

local function getLampChipId()
  if (detachConf ~= nil) then
    print("Lamp chip id: ", detachConf.serverid)
    lampServerChipId = detachConf.serverid
    conn()
  else
    -- print("Retrieve lamp server chip id...")
    -- print("http://"..netConf.serverip..":"..netConf.serverport.."/hardware/chipid")

    http.get("http://"..netConf.serverip..":"..netConf.serverport.."/hardware/chipid", nil, function(code, data)
      if (code < 0) then
        -- print("HTTP request failed")
        if (lampChipRequestAttempts > 3) then
          fileSystem.clearSettings("config.net")

          tmr.delay(1000)
          node.restart()
        else
          lampChipRequestAttempts = lampChipRequestAttempts + 1
          -- print("Attempt to get lamp server chip id in 3 sec...")
          tmr.delay(3000)
          getLampChipId()
        end
      else
        -- print("Lamp chip id: " .. data)
        lampServerChipId = data
        print("mqttsub get lamp chip success: ", node.heap())
        conn()
      end
    end)
  end
end

-- Reconnect to MQTT when we receive an "offline" message.
local function reconn()
  -- print("Disconnected!")
  isMqttAlive = false
  listen(false)

  -- print("Attempt to reconnect in 3 sec...")
  print("mqttsub reconn attempt: ", node.heap())
  tmr.delay(3000)
  conn()
end

local function onMsg(_client, topic, data)
  -- print(topic .. ":" )
  if data ~= nil then
    print(data)

    print("mqttsub message received: ", node.heap())
    local conf = sjson.decode(data)

    if (conf.locked == true) then -- new conf data
      if (lockConf == nil) then -- old conf data
        fileSystem.dumpSettings("lock.conf", {
          lockid = conf.lockid
        })
      end
    else
      if (lockConf ~= nil) then -- old conf data
        fileSystem.clearSettings("lock.conf")
      end
    end

    if (conf.detached == true) then -- new conf data
      if (detachConf == nil) then -- old conf data
        fileSystem.dumpSettings("detach.conf", {
          serverid = lampServerChipId
        })

        tmr.delay(1000)
        node.restart()
      end
    else
      if (detachConf ~= nil) then -- old conf data
        fileSystem.clearSettings("detach.conf")

        tmr.delay(1000)
        node.restart()
      end
    end

    if (conf.active == false) then -- new conf data
      if (deviceConf.active == true) and (detachConf == nil) then -- old conf data
        http.get("http://"..netConf.serverip..":"..netConf.serverport.."/alertoff", nil, nil)
      end
    end

    deviceConf = conf

    -- for k,v in pairs(deviceConf) do
    --   -- print(k, v)
    -- end
  end
end

local function makeConn()
  collectgarbage()

  print("mqttsub start: ", node.heap())
  mqttBroker = mqtt.Client(deviceId, mqttConf.brokerKeepAlive, mqttConf.brokerUsr, mqttConf.brokerPwd)
  -- Set up the event callbacks
  -- print("Setting up callbacks")
  -- mqttBroker:on("connect", function(device) -- print ("connected") end)
  mqttBroker:on("offline", reconn)
  -- on publish message receive event
  mqttBroker:on("message", onMsg)
  getLampChipId()
  -- Connect to the Broker
  -- conn()
end

makeConn()
