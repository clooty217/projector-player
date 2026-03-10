# typed: false

require "open3"
require "shellwords"

class AudioService
  Sink = Struct.new(:index, :name, :description, :state, :default, keyword_init: true)

  def list_sinks
    default_sink = current_default_sink
    output, _ = run("pactl list sinks short")
    output.each_line.filter_map do |line|
      parts = line.strip.split("\t")
      next if parts.length < 3
      name = parts[1]
      state = parts[4]&.downcase || "unknown"
      Sink.new(
        index: parts[0].to_i,
        name: name,
        description: sink_description(name),
        state: state,
        default: name == default_sink
      )
    end
  end

  def set_default_sink(sink_name)
    _, status = run("pactl set-default-sink #{Shellwords.escape(sink_name)}")
    move_active_streams(sink_name)
    { success: status.success?, sink: sink_name }
  end

  private

  def current_default_sink
    output, _ = run("pactl get-default-sink")
    output.strip
  end

  def sink_description(sink_name)
    output, _ = run("pactl list sinks")
    current_sink = false
    output.each_line do |line|
      if line.match?(/Name:\s/)
        current_sink = line.strip.end_with?(sink_name)
      end
      if current_sink && line =~ /Description:\s*(.+)/
        return $1.strip
      end
    end
    sink_name
  end

  def move_active_streams(sink_name)
    output, _ = run("pactl list sink-inputs short")
    output.each_line do |line|
      stream_id = line.strip.split("\t").first
      next unless stream_id&.match?(/\A\d+\z/)
      run("pactl move-sink-input #{stream_id} #{Shellwords.escape(sink_name)}")
    end
  end

  def run(cmd)
    Open3.capture2e(cmd)
  end
end
