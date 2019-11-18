-- mqttsub.lua

local mqttConf = dofile("broker.lc")

local mqttBroker = nil
local deviceId = node.chipid()
local lampChipRequestAttempts = 1
local mqttReconnectAttempts = 1

local function mqttBrokerConfTopic()
  return "lampwireless/" .. lampServerChipId .. "/device/" .. deviceId .. "/conf"
end

local function mqttBrokerStatusTopic()
  return "lampwireless/" .. lampServerChipId .. "/device/" .. deviceId .. "/status"
end

local function offlineMessage()
  return {["id"] = deviceId, ["type"] = deviceType, ["status"] = "offline"}
end

local function onlineMessage()
  return {["id"] = deviceId, ["type"] = deviceType, ["status"] = "online"}
end

local function setOnlineStatus()
  bootLedTick:stop()
  pwm.setduty(rRgbLedPin, 1023)
  pwm.setduty(gRgbLedPin, 1023)
  pwm.setduty(bRgbLedPin, 1023)
  gpio.write(greenLedPin, gpio.HIGH)
end

local function conn()
  print("Connecting to broker " .. mqttConf.brokerHost .. ":" .. tostring(mqttConf.brokerPort) .. " with usr: " .. mqttConf.brokerUsr .. " pwd: " .. mqttConf.brokerPwd .. "...")
  -- Set up last will testament
  mqttBroker:lwt(mqttBrokerStatusTopic(), sjson.encode(offlineMessage()), 1, 1)
  -- Connect to broker
  mqttBroker:connect(mqttConf.brokerHost, mqttConf.brokerPort, false, function(client)
    mqttReconnectAttempts = 1
    setOnlineStatus()
    -- dofile("pir.lc")

    print("Publishing online message to topic: " .. mqttBrokerStatusTopic() .. "...")
    client:publish(mqttBrokerStatusTopic(), sjson.encode(onlineMessage()), 1, 1, function(client)
      print("Subscribing to topic " .. mqttBrokerConfTopic() .. "...")
      -- subscribe topic with qos = 0
      client:subscribe(mqttBrokerConfTopic(), 0, function(client)
        -- setOnlineStatus()
        -- dofile("pir.lc")
      end)
    end)
  end,
  function(client, reason)
    print("Failed to connect: " .. reason)
    setOnlineStatus()
    -- dofile("pir.lc")
  end)
end

local function getLampChipId()
  print("Retrieve lamp server chip id...")

  print("Lamp chip id: " .. "1234567")
  lampServerChipId = "1234567"
  conn()

  -- print("http://"..lampServerIp..":"..lampServerPort.."/hardware/chipid")

  -- http.get("http://"..lampServerIp..":"..lampServerPort.."/hardware/chipid", nil, function(code, data)
  --   if (code < 0) then
  --     print("HTTP request failed")
  --     if (lampChipRequestAttempts > 3) then
  --       setOnlineStatus()
  --       dofile("pir.lc")
  --     else
  --       lampChipRequestAttempts = lampChipRequestAttempts + 1
  --       getLampChipId()
  --     end
  --   else
  --     print("Lamp chip id: " .. data)
  --     lampServerChipId = data
  --     conn()
  --   end
  -- end)
end

-- Reconnect to MQTT when we receive an "offline" message.
local function reconn()
  print("Disconnected, reconnecting....")
  if (mqttReconnectAttempts > 3) then
    mqttReconnectAttempts = 1
  else
    mqttReconnectAttempts = mqttReconnectAttempts + 1
    conn()
  end
end

local function onMsg(_client, topic, data)
  print(topic .. ":" )
  if data ~= nil then
    print(data)

    deviceConf = sjson.decode(data)

    -- for k,v in pairs(deviceConf) do
    --   print(k, v)
    -- end
  end
end

local function makeConn()
  mqttBroker = mqtt.Client(mqttBrokerClientId, mqttConf.brokerKeepAlive, mqttConf.brokerUsr, mqttConf.brokerPwd)
  -- Set up the event callbacks
  print("Setting up callbacks")
  -- mqttBroker:on("connect", function(device) print ("connected") end)
  mqttBroker:on("offline", reconn)
  -- on publish message receive event
  mqttBroker:on("message", onMsg)
  getLampChipId()
  -- Connect to the Broker
  -- conn()
end

makeConn()
