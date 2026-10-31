# frozen_string_literal: true

require "solaredge/modbus/codec"
require "solaredge/modbus/error"
require "solaredge/modbus/transport"

module SolarEdge
    module Modbus
        # What every SolarEdge device shares: a connection, reading one
        # register or all of them, writing one. A subclass supplies
        # REGISTERS (name => Register), WORDORDER (:big or :little) and,
        # where some registers want the other order, LITTLE_ENDIAN (their
        # addresses).
        #
        # A read that fails for a reason that may pass (no connection, a
        # timeout, a busy device) is tried again after each of
        # retry_delays, reconnecting first; then it raises. A device's
        # refusal (ModbusException#refusal?) is final at once. read_all
        # reads each batch in one request and decodes every register at
        # its own address.
        class Device
            WORDORDER = :big
            LITTLE_ENDIAN = [].freeze

            # Seconds before each further try: time for a busy device, or
            # for another client to let go of an inverter that takes one
            # at a time.
            RETRY_DELAYS = [0.5, 1.0].freeze

            attr_reader :transport, :unit, :retry_delays

            # Built from host and port, a transport, or parent: a device
            # whose connection, unit and retry delays this one shares.
            # rubocop:disable Metrics/ParameterLists -- three ways to
            # reach a device and two settings, all keywords.
            def initialize(host: nil, port: nil, unit: nil, transport: nil,
                           parent: nil, retry_delays: nil)
                @transport = parent&.transport || transport ||
                             Transport.new(host, port)
                @unit, @retry_delays = settings(parent, unit, retry_delays)
            end
            # rubocop:enable Metrics/ParameterLists

            def registers = self.class::REGISTERS

            def connected? = @transport.connected?
            def connect = @transport.connect
            def disconnect = @transport.close

            # The register's value, or nil when the device says it is
            # not implemented. Raises Error when it cannot be read.
            def read(key)
                reg = find(key)
                raw = read_raw(reg.address, reg.length)
                Codec.decode(raw, reg.dtype, wordorder(reg))
            end

            # value * 10**scale, read from the two registers, or nil when
            # either is not implemented.
            def scaled(key, scale)
                value = read(key) or return
                exponent = read(scale) or return
                value * (10.0**exponent)
            end

            # Every register of the device's batches; a batch the device
            # refuses is left out, any other failure raises.
            def read_all
                batches.each_with_object({}) do |group, acc|
                    acc.merge!(read_batch(group))
                end
            end

            # nil once written; raises Error otherwise. A string is
            # padded with NULs to its register's length.
            def write(key, value)
                reg = find(key)
                words = Codec.encode(value, reg.dtype, wordorder(reg),
                                     length: reg.length)
                @transport.write_registers(@unit, reg.address, words)
                nil
            end

            private

            def settings(parent, unit, delays)
                if parent
                    [unit || parent.unit, delays || parent.retry_delays]
                else
                    [unit || 1, delays || RETRY_DELAYS]
                end
            end

            def find(key)
                registers.fetch(key) do
                    raise Error, "solaredge: unknown register #{key}"
                end
            end

            def wordorder(reg)
                little = self.class::LITTLE_ENDIAN.include?(reg.address)
                little ? :little : self.class::WORDORDER
            end

            def batches
                registers.group_by { |_, r| r.batch }.sort.map(&:last)
            end

            def read_batch(group)
                addr_min = group.map { |_, r| r.address }.min
                addr_max = group.map { |_, r| r.address + r.length }.max
                raw = read_raw(addr_min, addr_max - addr_min)
                decode_batch(group, raw, addr_min)
            rescue ModbusException => e
                raise unless e.refusal?
                {}
            end

            def decode_batch(group, raw, addr_min)
                group.to_h do |key, reg|
                    slice = raw[reg.address - addr_min, reg.length]
                    [key, Codec.decode(slice, reg.dtype, wordorder(reg))]
                end
            end

            def read_raw(address, length)
                tries = 0
                begin
                    try_read(address, length)
                rescue Error => e
                    raise if final?(e, tries)
                    sleep @retry_delays[tries]
                    tries += 1
                    retry
                end
            end

            def final?(error, tries)
                return true if tries >= @retry_delays.size
                error.is_a?(ModbusException) && error.refusal?
            end

            def try_read(address, length)
                connect unless connected?
                raw = @transport.read_registers(:holding, @unit, address,
                                                length)
                return raw if raw.size == length
                raise Error, "solaredge: #{raw.size} registers for #{length}"
            end
        end
    end
end
