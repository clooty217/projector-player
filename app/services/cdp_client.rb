# typed: false

require "net/http"
require "json"
require "socket"
require "securerandom"

# Minimal Chrome DevTools Protocol client using only Ruby stdlib.
# Connects to a Chromium instance launched with --remote-debugging-port.
class CdpClient
  class Error < StandardError; end

  def initialize(host: "127.0.0.1", port: 9222)
    @host = host
    @port = port
  end

  def evaluate(expression)
    targets = fetch_targets
    raise Error, "No CDP targets found at #{@host}:#{@port}" if targets.empty?

    page_targets = targets.select { |t| t["type"] == "page" }
    iframe_targets = targets.select { |t| t["type"] == "iframe" }

    # Try page targets first, then iframes — the video element could be in either
    (page_targets + iframe_targets).each do |target|
      ws_url = target["webSocketDebuggerUrl"]
      next unless ws_url

      result = ws_evaluate(ws_url, expression)
      return result if result && !result.dig("result", "subtype")&.==("error")
    rescue => e
      Rails.logger.debug "CDP: skipping target #{target['id']}: #{e.message}"
      next
    end

    raise Error, "Could not evaluate expression on any target"
  end

  private

  def fetch_targets
    uri = URI("http://#{@host}:#{@port}/json")
    response = Net::HTTP.get(uri)
    JSON.parse(response)
  rescue Errno::ECONNREFUSED
    raise Error, "Chromium not reachable at #{@host}:#{@port}. Is it running with --remote-debugging-port=#{@port}?"
  end

  def ws_evaluate(ws_url, expression)
    uri = URI(ws_url)
    socket = TCPSocket.new(uri.host, uri.port)

    begin
      ws_handshake(socket, uri)
      payload = { id: 1, method: "Runtime.evaluate", params: { expression: expression } }
      ws_send_text(socket, JSON.generate(payload))
      response = ws_read_text(socket)
      JSON.parse(response)
    ensure
      socket.close
    end
  end

  def ws_handshake(socket, uri)
    key = Base64.strict_encode64(SecureRandom.random_bytes(16))

    socket.write(
      "GET #{uri.path} HTTP/1.1\r\n" \
      "Host: #{uri.host}:#{uri.port}\r\n" \
      "Upgrade: websocket\r\n" \
      "Connection: Upgrade\r\n" \
      "Sec-WebSocket-Key: #{key}\r\n" \
      "Sec-WebSocket-Version: 13\r\n" \
      "\r\n"
    )

    status_line = socket.gets
    raise Error, "WebSocket handshake failed: #{status_line}" unless status_line&.include?("101")

    # Consume remaining headers
    loop do
      line = socket.gets
      break if line.nil? || line.strip.empty?
    end
  end

  # Send a masked text frame (clients must mask per RFC 6455)
  def ws_send_text(socket, text)
    bytes = text.encode("UTF-8").bytes
    frame = [0x81].pack("C") # FIN + text opcode

    if bytes.length < 126
      frame << [bytes.length | 0x80].pack("C")
    elsif bytes.length < 65536
      frame << [126 | 0x80].pack("C")
      frame << [bytes.length].pack("n")
    else
      frame << [127 | 0x80].pack("C")
      frame << [bytes.length].pack("Q>")
    end

    mask_key = SecureRandom.random_bytes(4)
    frame << mask_key
    masked = bytes.each_with_index.map { |b, i| b ^ mask_key.getbyte(i % 4) }
    frame << masked.pack("C*")

    socket.write(frame)
  end

  # Read a single text frame (server frames are unmasked)
  def ws_read_text(socket)
    first = socket.readpartial(2)
    length = first.getbyte(1) & 0x7F

    if length == 126
      length = socket.readpartial(2).unpack1("n")
    elsif length == 127
      length = socket.readpartial(8).unpack1("Q>")
    end

    data = +""
    while data.bytesize < length
      data << socket.readpartial(length - data.bytesize)
    end

    data.force_encoding("UTF-8")
  end
end
