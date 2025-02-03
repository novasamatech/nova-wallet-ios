desc "Register new devices"
desc "This lane will register new devices and update profiles via match"
lane :register do
  device_name = prompt(text: "Enter the device name: ")
  device_udid = prompt(text: "Enter the device UDID: ")
  device_hash = {}
  device_hash[device_name] = device_udid
  register_devices(devices: device_hash)
end
