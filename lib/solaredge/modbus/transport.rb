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
        #
        # A reply is taken only if it answers the request just sent: its
        # transaction id, protocol (0) and unit must match, and it must
        # arrive whole within `timeout` seconds of the request. Anything
        # else closes the connection, so a reply that comes late is
        # never read as the answer to the next request.
        class Transport
            FUNCTION = { holding: 3, input: 4, write: 16 }.freeze

            # MBAP length: the unit byte and a PDU of 1 to 253 bytes.
            LENGTHS = 2..254

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
                return if connected?
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
                function = FUNCTION.fetch(type)
                exchange(unit, [function, address, count].pack("Cnn")) do |pdu|
                    Frame.registers(pdu, function, count)
                end
            end

            # Named after pymodbus's own write_registers, not a
            # predicate: true, or an Error raised.
            # rubocop:disable-next Naming/PredicateMethod
            def write_registers(unit, address, values)
                exchange(unit, Frame.write_request(address, values)) do |pdu|
                    Frame.confirm_write(pdu, address, values.size)
                end
                true
            end

            private

            # Sends one request and hands its reply to the block; any
            # failure from the send on closes the connection.
            def exchange(unit, pdu)
                connect
                @tid = (@tid + 1) & 0xffff
                write_frame([@tid, 0, pdu.bytesize + 1, unit].pack("nnnC") +
                            pdu)
                yield read_reply(@tid, unit)
            rescue Error
                close
                raise
            end

            def write_frame(frame)
                @socket.write(frame)
            rescue SystemCallError, IOError => e
                raise Error, "solaredge: write: #{e.message}"
            end

            def read_reply(tid, unit)
                deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) +
                           @timeout
                header = read_exact(7, deadline).unpack("nnnC")
                Frame.check_header(header, tid, unit, LENGTHS)
                read_exact(header[2] - 1, deadline)
            end

            def read_exact(count, deadline)
                buf = +""
                buf << read_some(count - buf.bytesize, deadline) while
                    buf.bytesize < count
                buf
            end

            def read_some(count, deadline)
                left = deadline - Process.clock_gettime(Process::CLOCK_MONOTONIC)
                raise Error, "solaredge: read timed out" unless
                    left.positive? && @socket.wait_readable(left)
                chunk = @socket.read_nonblock(count, exception: false)
                raise Error, "solaredge: connection closed" if chunk.nil?
                chunk == :wait_readable ? "" : chunk
            rescue SystemCallError, IOError => e
                raise Error, "solaredge: read: #{e.message}"
            end
        end
    end
end
