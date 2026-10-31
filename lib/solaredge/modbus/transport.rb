# frozen_string_literal: true

require "socket"

module SolarEdge
    module Modbus
        # Modbus TCP framing over a real TCPSocket: the MBAP header
        # (pymodbus-dev/pymodbus framer/socket.py, dev branch, fetched
        # 2026-10-30 -- "[ MBAP Header ][ Function Code][ Data ]
        # [tid 2b][pid 2b][length 2b][uid 1b]", length = uid + function
        # code + data) wraps a PDU of function code 3 (Read Holding
        # Registers), 4 (Read Input Registers) or 16 (Write Multiple
        # Registers): the only codes pymodbus's ModbusTcpClient issues
        # for read_holding_registers/read_input_registers/
        # write_registers, which is all nmakel/solaredge_modbus ever
        # calls. Request/response layout and the exception response
        # (function code | 0x80, one exception-code byte): pymodbus-dev/
        # pymodbus pdu/register_message.py and pdu/exceptionresponse.py,
        # same fetch. Device holds the injectable seam (a Transport, or
        # any object answering to the same four methods); tests use a
        # fake one and never open a socket.
        class Transport
            FUNCTION = { holding: 3, input: 4, write: 16 }.freeze

            def initialize(host, port, open_timeout: 3, timeout: 3)
                @host = host
                @port = port
                @open_timeout = open_timeout
                @timeout = timeout
                @socket = nil
                @tid = 0
            end

            def connected? = !@socket.nil?

            def connect
                @socket = Socket.tcp(@host, @port,
                                     connect_timeout: @open_timeout)
            rescue SystemCallError, SocketError, IOError => e
                raise Error, "solaredge: #{@host}:#{@port}: #{e.message}"
            end

            def close
                @socket&.close
            ensure
                @socket = nil
            end

            def read_registers(type, unit, address, count)
                pdu = [FUNCTION.fetch(type), address, count].pack("Cnn")
                decode_read(transact(unit, pdu), FUNCTION.fetch(type))
            end

            # Named after pymodbus's own write_registers, not a
            # predicate, even though confirm_write? makes it return a
            # boolean (true, or an Error raised on an exception
            # response).
            # rubocop:disable-next Naming/PredicateMethod
            def write_registers(unit, address, values)
                pdu = encode_write(address, values)
                confirm_write?(transact(unit, pdu))
            end

            private

            def transact(unit, pdu)
                connect unless connected?
                write_frame(mbap(unit, pdu) + pdu)
                read_response
            end

            def mbap(unit, pdu)
                @tid = (@tid + 1) & 0xffff
                [@tid, 0, pdu.bytesize + 1, unit].pack("nnnC")
            end

            def write_frame(frame)
                @socket.write(frame)
            rescue SystemCallError, IOError => e
                close
                raise Error, "solaredge: write: #{e.message}"
            end

            def read_response
                header = read_exact(7)
                _tid, _proto, length = header.unpack("nnn")
                read_exact(length - 1)
            end

            def read_exact(count)
                buf = +""
                buf << read_some(count - buf.bytesize) while
                    buf.bytesize < count
                buf
            end

            def read_some(count)
                raise Error, "solaredge: read timed out" unless
                    @socket.wait_readable(@timeout)
                chunk = @socket.read(count)
                return chunk unless chunk.nil? || chunk.empty?
                close
                raise Error, "solaredge: connection closed"
            rescue SystemCallError, IOError => e
                close
                raise Error, "solaredge: read: #{e.message}"
            end

            def decode_read(pdu, function)
                check_exception(pdu, function)
                byte_count = pdu.getbyte(1)
                pdu[2, byte_count].unpack("n*")
            end

            def confirm_write?(pdu)
                check_exception(pdu, FUNCTION.fetch(:write))
                true
            end

            def check_exception(pdu, function)
                return if pdu.getbyte(0) == function
                raise Error, "solaredge: Modbus exception " \
                             "#{pdu.getbyte(1)} on function #{function}"
            end

            def encode_write(address, values)
                [FUNCTION.fetch(:write), address, values.size,
                 values.size * 2, *values]
                    .pack("Cnn C n#{values.size}")
            end
        end
    end
end
