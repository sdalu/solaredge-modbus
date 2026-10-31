# frozen_string_literal: true

module SolarEdge
    module Modbus
        # Builds and checks the PDUs Transport exchanges (see
        # transport.rb for the sources): nothing from the wire is used
        # before its lengths and echoes are found to agree with the
        # request, and each disagreement is an Error.
        module Frame
            WRITE = Transport::FUNCTION.fetch(:write)

            module_function

            def write_request(address, values)
                [WRITE, address, values.size, values.size * 2, *values]
                    .pack("Cnn C n#{values.size}")
            end

            def check_header(header, tid, unit, lengths)
                r_tid, protocol, length, r_unit = header
                raise Error, "solaredge: MBAP length #{length}" unless
                    lengths.cover?(length)
                return if [r_tid, protocol, r_unit] == [tid, 0, unit]
                raise Error, "solaredge: reply #{r_tid}/#{protocol}/" \
                             "#{r_unit} to request #{tid}/0/#{unit}"
            end

            def registers(pdu, function, count)
                check_function(pdu, function)
                byte_count = pdu.getbyte(1)
                unless byte_count == 2 * count && pdu.bytesize == 2 + byte_count
                    raise Error, "solaredge: #{pdu.bytesize - 1} bytes " \
                                 "for #{count} registers"
                end
                pdu.byteslice(2, byte_count).unpack("n*")
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
                    raise Error, "solaredge: Modbus exception " \
                                 "#{pdu.getbyte(1)} on function #{function}"
                end
                raise Error, "solaredge: function #{code.inspect} in " \
                             "reply to #{function}"
            end
        end
    end
end
