local mdnsTick = tmr.create()

mdnsTick:alarm(20000, tmr.ALARM_AUTO, function()
  print("Registering mdn service...")

  mdns.register(
    "lampwireless", {
      description="Light notifications",
      service="lampwireless",
      port=80
    }
  )
end)
