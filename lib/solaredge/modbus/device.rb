# frozen_string_literal: true

require "solaredge/modbus/codec"
require "solaredge/modbus/transport"

module SolarEdge
    module Modbus
        # What every SolarEdge device shares: a connection, reading one
        # register or all of them, writing one. A subclass supplies
        # REGISTERS (name => Register), WORDORDER (:big or :little) and,
        # where some registers want the other order, LITTLE_ENDIAN (their
        # addresses).
        #
        # A read is tried up to RETRIES times, reconnecting first if
        # needed; then it raises. read_all reads each batch in one
        # request and decodes every register at its own address.
        class Device
            WORDORDER = :big
            LITTLE_ENDIAN = [].freeze

            RETRIES = 3

            attr_reader :transport, :unit

            def initialize(host: nil, port: nil, unit: nil, transport: nil,
                           parent: nil)
                if parent
                    @transport = parent.transport
                    @unit = unit || parent.unit
                else
                    @transport = transport || Transport.new(host, port)
                    @unit = unit || 1
                end
            end

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

            # Every register of the device's batches; a batch the device
            # refuses (ModbusException) is left out, any other failure
            # raises.

            def read_all
                batches.each_with_object({}) do |group, acc|
                    acc.merge!(read_batch(group))
                end
            end

            # nil once written; raises Error otherwise. A string is
            # padded with NULs to its register's length.
            def write(key, value)
                reg = find(key)
                @transport.write_registers(@unit, reg.address,
                                           encode(key, reg, value))
                nil
            end

            private

            def find(key)
                registers.fetch(key) do
                    raise Error, "solaredge: unknown register #{key}"
                end
            end

            # Never more registers than the register has: they would
            # land on the next one.
            def encode(key, reg, value)
                words = Codec.encode(value, reg.dtype, wordorder(reg))
                if words.size > reg.length
                    raise Error, "solaredge: #{key} holds #{reg.length} " \
                                 "registers, not #{words.size}"
                end
                return words unless reg.dtype == :string
                words + ([0] * (reg.length - words.size))
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
            rescue ModbusException
                {}
            end

            def decode_batch(group, raw, addr_min)
                group.to_h do |key, reg|
                    slice = raw[reg.address - addr_min, reg.length]
                    [key, Codec.decode(slice, reg.dtype, wordorder(reg))]
                end
            end

            # Up to RETRIES tries, reconnecting as needed, then the last
            # failure is raised. A ModbusException is the device's
            # answer, which another try would not change.
            def read_raw(address, length)
                failure = nil
                RETRIES.times do
                    return try_read(address, length)
                rescue ModbusException
                    raise
                rescue Error => e
                    failure = e
                end
                raise failure
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
