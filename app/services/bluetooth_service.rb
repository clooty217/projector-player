# typed: false

require "open3"

class BluetoothService
  Device = Struct.new(:mac, :name, :connected, :paired, :trusted, keyword_init: true)

  def paired_devices
    output, _ = run("bluetoothctl devices Paired")
    parse_device_list(output).map do |mac, name|
      info = device_info(mac)
      Device.new(mac: mac, name: name, connected: info[:connected], paired: true, trusted: info[:trusted])
    end
  end

  def scan(seconds: 8)
    run("bluetoothctl --timeout #{seconds} scan on")
    output, _ = run("bluetoothctl devices")
    parse_device_list(output).map do |mac, name|
      info = device_info(mac)
      Device.new(mac: mac, name: name, connected: info[:connected], paired: info[:paired], trusted: info[:trusted])
    end
  end

  def connect(mac)
    _, paired_status = run("bluetoothctl pair #{shellescape(mac)}")
    run("bluetoothctl trust #{shellescape(mac)}")
    output, status = run("bluetoothctl connect #{shellescape(mac)}")
    { success: output.include?("successful"), output: output.strip }
  end

  def disconnect(mac)
    output, status = run("bluetoothctl disconnect #{shellescape(mac)}")
    { success: output.include?("successful"), output: output.strip }
  end

  def remove(mac)
    run("bluetoothctl disconnect #{shellescape(mac)}")
    output, _ = run("bluetoothctl remove #{shellescape(mac)}")
    { success: output.include?("removed") || output.include?("not available"), output: output.strip }
  end

  private

  def device_info(mac)
    output, _ = run("bluetoothctl info #{shellescape(mac)}")
    {
      connected: output.match?(/Connected:\s*yes/i),
      paired: output.match?(/Paired:\s*yes/i),
      trusted: output.match?(/Trusted:\s*yes/i)
    }
  end

  def parse_device_list(output)
    output.scan(/Device\s+([\dA-F:]{17})\s+(.+)/i)
  end

  def run(cmd)
    Open3.capture2e(cmd)
  end

  def shellescape(str)
    Shellwords.escape(str)
  end
end
