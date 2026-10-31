# frozen_string_literal: true

module SolarEdge
    module Modbus
        # The shared machinery of __init__.py's SolarEdge base class
        # (@fd3ce7a, __init__.py:189-458; see modbus.rb for the
        # commit): connect, retry, read one register or a whole batch,
        # write one register. A subclass supplies REGISTERS (a name =>
        # Register hash), WORDORDER (:big or :little) and, where
        # upstream has one, LITTLE_ENDIAN (addresses that want the
        # opposite wordorder -- only Inverter's power-control and
        # StorEdge-settings registers do).
        #
        # Deliberately simplified from upstream's retry loop
        # (__init__.py:269-287: reconnect-then-`continue` burns a retry
        # without reading; here, a failed connect or read just tries the
        # next attempt): the externally visible result is the same --
        # up to `retries` tries, each one reconnecting first if needed.
        #
        # read_all decodes each register from its own address, with its
        # own address's wordorder. Upstream's `_read_all`
        # (__init__.py:365-411) takes the wordorder from the batch's
        # start address (the same on every table here) and advances its
        # decoder by the dtype's width but its offset by the table's
        # length, so a register after a uint16 of length 2 (battery
        # event_log) is read one word early.
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

            def read(key)
                reg = find(key)
                raw = read_raw(reg.address, reg.length, reg.rtype)
                return false if raw.nil?
                Codec.decode(raw, reg.dtype, reg.vtype, wordorder(reg))
            end

            def read_all(rtype = :holding)
                batches(rtype).each_with_object({}) do |group, acc|
                    acc.merge!(read_batch(group))
                end
            end

            def write(key, value)
                reg = find(key)
                values = Codec.encode(value, reg.dtype, wordorder(reg))
                @transport.write_registers(@unit, reg.address, values)
            end

            private

            def find(key)
                registers.fetch(key) do
                    raise Error, "solaredge: unknown register #{key}"
                end
            end

            def wordorder(reg)
                little = self.class::LITTLE_ENDIAN.include?(reg.address)
                little ? :little : self.class::WORDORDER
            end

            def batches(rtype)
                registers.select { |_, r| r.rtype == rtype }
                         .group_by { |_, r| r.batch }.sort.map(&:last)
            end

            def read_batch(group)
                addr_min = group.map { |_, r| r.address }.min
                addr_max = group.map { |_, r| r.address + r.length }.max
                rtype    = group.first.last.rtype
                raw = read_raw(addr_min, addr_max - addr_min, rtype)
                raw.nil? ? {} : decode_batch(group, raw, addr_min)
            end

            def decode_batch(group, raw, addr_min)
                group.to_h do |key, reg|
                    slice = raw[reg.address - addr_min, reg.length]
                    [key, Codec.decode(slice, reg.dtype, reg.vtype,
                                       wordorder(reg))]
                end
            end

            def read_raw(address, length, rtype)
                RETRIES.times do
                    registers_read = try_read(address, length, rtype)
                    return registers_read if registers_read&.size == length
                end
                nil
            end

            def try_read(address, length, rtype)
                connect unless connected?
                @transport.read_registers(rtype, @unit, address, length)
            rescue Error
                nil
            end
        end
    end
end
