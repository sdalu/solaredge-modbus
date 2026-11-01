# frozen_string_literal: true

require "socket"

require "solaredge/modbus/error"
require "solaredge/modbus/frame"

module SolarEdge
    module Modbus
        # Modbus TCP over a socket: each request is an MBAP header
        # (transaction id, protocol 0, length, unit) and a PDU of
        # function code 3 (read holding registers), 4 (read input
        # registers) or 16 (write multiple registers). Frame builds and
        # checks the PDUs. Device takes any object answering the same
        # five methods (connected?, connect, close, read_registers,
        # write_registers), which is how the tests run without one.
        #
        # A reply is taken only if it answers the request just sent: its
        # transaction id, protocol (0) and unit must match, and it must
        # arrive whole within `timeout` seconds of the request. A reply
        # to another transaction is skipped; anything else closes the
        # connection, so a reply that comes late is never read as the
        # answer to the next request.
        #
        # A SolarEdge inverter hands a late reply to a timed-out request
        # to whichever client connects next. So each connection starts
        # its transaction ids at random, where a fixed start would let
        # the leftover match, and anything already readable before a
        # request is discarded: it cannot answer a request not yet sent.
        class Transport
            # MBAP length: the unit byte and a PDU of 1 to 253 bytes.
            LENGTHS = 2..254

            # random: what draws each connection's first transaction id.
            def initialize(host, port, open_timeout: 3, timeout: 3,
                           random: Random.new)
                @host = host
                @port = port
                @open_timeout = open_timeout
                @timeout = timeout
                @random = random
                @socket = nil
            end

            def connected? = !@socket.nil?

            def connect
                return if connected?
                @socket = Socket.tcp(@host, @port,
                                     connect_timeout: @open_timeout)
                @tid = @random.rand(0x10000)
            rescue SystemCallError, SocketError, IOError => e
                raise Error, "solaredge: #{@host}:#{@port}: #{e.message}"
            end

            def close
                @socket&.close
            ensure
                @socket = nil
            end

            def read_registers(type, unit, address, count)
                function = Frame::FUNCTION.fetch(type)
                exchange(unit, [function, address, count].pack("Cnn")) do |pdu|
                    Frame.registers(pdu, function, count)
                end
            end

            # nil once the device confirms the write; raises otherwise.
            def write_registers(unit, address, values)
                exchange(unit, Frame.write_request(address, values)) do |pdu|
                    Frame.confirm_write(pdu, address, values.size)
                end
                nil
            end

            private

            # Sends one request and hands its reply to the block. Any
            # failure from the send on closes the connection, except the
            # device's exception reply: that is a whole, matching answer.
            def exchange(unit, pdu)
                connect
                drain
                tid = next_tid
                write_frame([tid, 0, pdu.bytesize + 1, unit].pack("nnnC") + pdu)
                yield read_reply(tid, unit)
            rescue ModbusException
                raise
            rescue Error
                close
                raise
            end

            def next_tid = @tid = (@tid + 1) & 0xffff

            def write_frame(frame)
                @socket.write(frame)
            rescue SystemCallError, IOError => e
                raise Error, "solaredge: write: #{e.message}"
            end

            def read_reply(tid, unit)
                deadline = now + @timeout
                loop do
                    header = read_exact(7, deadline).unpack("nnnC")
                    ours = Frame.ours?(header, tid, unit, LENGTHS)
                    pdu = read_exact(header[2] - 1, deadline)
                    return pdu if ours
                end
            end

            # Discards whatever is readable before a request.
            def drain
                loop do
                    chunk = @socket.read_nonblock(4096, exception: false)
                    return if chunk == :wait_readable
                    raise Error, "solaredge: connection closed" if chunk.nil?
                end
            rescue SystemCallError, IOError => e
                raise Error, "solaredge: read: #{e.message}"
            end

            def read_exact(count, deadline)
                buf = +""
                buf << read_some(count - buf.bytesize, deadline) while
                    buf.bytesize < count
                buf
            end

            def readable?(deadline)
                left = deadline - now
                left.positive? && !@socket.wait_readable(left).nil?
            end

            def now = Process.clock_gettime(Process::CLOCK_MONOTONIC)

            def read_some(count, deadline)
                raise Error, "solaredge: read timed out" unless
                    readable?(deadline)
                chunk = @socket.read_nonblock(count, exception: false)
                raise Error, "solaredge: connection closed" if chunk.nil?
                chunk == :wait_readable ? "" : chunk
            rescue SystemCallError, IOError => e
                raise Error, "solaredge: read: #{e.message}"
            end
        end
    end
end
