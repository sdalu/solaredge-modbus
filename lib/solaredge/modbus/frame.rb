# frozen_string_literal: true

require "solaredge/modbus/error"

module SolarEdge
    module Modbus
        # Builds and checks the PDUs Transport exchanges (see
        # transport.rb for the sources): nothing from the wire is used
        # before its lengths and echoes are found to agree with the
        # request, and each disagreement is an Error.
        module Frame
            # Read holding registers, read input registers, write
            # multiple registers.
            FUNCTION = { holding: 3, input: 4, write: 16 }.freeze
            WRITE = FUNCTION.fetch(:write)

            module_function

            def write_request(address, values)
                [WRITE, address, values.size, values.size * 2, *values]
                    .pack("Cnn C n#{values.size}")
            end

            # header: [transaction id, protocol, length, unit]. true for
            # the reply to request tid, false for a reply to another
            # request (a late one, to be skipped); raises for a frame
            # that is not a Modbus TCP reply to this unit.
            def ours?(header, tid, unit, lengths)
                r_tid, protocol, length, r_unit = header
                raise Error, "solaredge: MBAP length #{length}" unless
                    lengths.cover?(length)
                raise Error, "solaredge: protocol #{protocol}" unless
                    protocol.zero?
                return false unless r_tid == tid
                return true if r_unit == unit
                raise Error, "solaredge: reply from unit #{r_unit} to #{unit}"
            end

            def registers(pdu, function, count)
                check_function(pdu, function)
                byte_count = pdu.getbyte(1)
                whole = byte_count == 2 * count &&
                        pdu.bytesize == 2 + byte_count
                return pdu.byteslice(2, byte_count).unpack("n*") if whole
                raise Error, "solaredge: #{pdu.bytesize - 1} bytes for " \
                             "#{count} registers"
            end

            def confirm_write(pdu, address, count)
                check_function(pdu, WRITE)
                echo = pdu.bytesize == 5 && pdu.byteslice(1, 4).unpack("nn")
                return if echo == [address, count]
                raise Error, "solaredge: write of #{count} at #{address} " \
                             "answered with #{echo.inspect}"
            end

            def check_function(pdu, function)
                code = pdu.getbyte(0)
                return if code == function
                if code == (function | 0x80) && pdu.bytesize == 2
                    raise ModbusException.new(pdu.getbyte(1), function)
                end
                raise Error, "solaredge: function #{code.inspect} in " \
                             "reply to #{function}"
            end
        end
    end
end
