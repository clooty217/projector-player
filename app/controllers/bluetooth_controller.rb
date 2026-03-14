# typed: true

class BluetoothController < ApplicationController
  skip_before_action :verify_authenticity_token
  before_action :set_service

  def devices
    render json: serialize(@bt.paired_devices)
  end

  def scan
    devices = @bt.scan(seconds: params.fetch(:seconds, 8).to_i)
    render json: serialize(devices)
  end

  def connect
    result = @bt.connect(params.require(:mac))
    render json: result
  end

  def disconnect
    result = @bt.disconnect(params.require(:mac))
    render json: result
  end

  def remove
    result = @bt.remove(params.require(:mac))
    render json: result
  end

  private

  def set_service
    @bt = BluetoothService.new
  end

  def serialize(devices)
    devices.map { |d| { mac: d.mac, name: d.name, connected: d.connected, paired: d.paired, trusted: d.trusted } }
  end
end
