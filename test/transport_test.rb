# frozen_string_literal: true

require "socket"

require "test_helper"

# Transport's Modbus TCP framing, checked byte for byte against a
# one-shot TCP server on 127.0.0.1 (never the network, never the
# inverter): the MBAP header, the read and write PDUs, and the
# exception reply.
class SolarEdgeTransportTest < Minitest::Test
    Transport = SolarEdge::Modbus::Transport
    Error     = SolarEdge::Modbus::Error

    def test_reads_holding_registers
        request = serve([0x1234, 0x5678]) do |transport|
            transport.read_registers(:holding, 1, 0x10, 2)
        end
        assert_equal [0x1234, 0x5678], @result
        assert_equal mbap_request(3, 0x10, 2), request
    end

    def test_writes_multiple_registers
        request = serve_write do |transport|
            transport.write_registers(1, 0x20, [9, 10])
        end
        assert_nil @result
        assert_equal write_request(0x20, [9, 10]), request
    end

    def test_an_exception_response_raises_its_code
        serve_exception(3, 2) do |transport|
            error = assert_raises(SolarEdge::Modbus::ModbusException) do
                transport.read_registers(:holding, 1, 0, 1)
            end
            assert_equal [2, 3], [error.code, error.function]
        end
    end

    def test_a_refused_connection_raises
        server = TCPServer.new("127.0.0.1", 0)
        port = server.addr[1]
        server.close
        transport = Transport.new("127.0.0.1", port, open_timeout: 1)
        assert_raises(Error) { transport.connect }
    end

    private

    # Runs `transport.read_registers(:holding, 1, 0x10, 2)`-style work
    # against a one-shot server answering with `registers`; returns the
    # bytes the server received, and stashes the transport call's own
    # result in @result.
    def serve(registers)
        pdu = ([3, registers.size * 2] + registers).pack("CCn*")
        with_server do |server, port|
            thread = Thread.new { answer(server, pdu) }
            transport = Transport.new("127.0.0.1", port)
            @result = yield(transport)
            thread.value
        end
    end

    def serve_write
        pdu = [16, 0x20, 2].pack("Cnn")
        with_server do |server, port|
            thread = Thread.new { answer(server, pdu) }
            transport = Transport.new("127.0.0.1", port)
            @result = yield(transport)
            thread.value
        end
    end

    def serve_exception(function, code)
        pdu = [function | 0x80, code].pack("CC")
        with_server do |server, port|
            thread = Thread.new { answer(server, pdu) }
            transport = Transport.new("127.0.0.1", port)
            yield(transport)
            thread.value
        end
    end

    def with_server
        server = TCPServer.new("127.0.0.1", 0)
        yield(server, server.addr[1])
    ensure
        server.close
    end

    # Accepts one connection, reads whatever the client sent, replies
    # with one MBAP frame (transaction id 1, unit 1) wrapping `pdu`,
    # and returns the request bytes read.
    def answer(server, pdu)
        conn = server.accept
        request = conn.recv(1024)
        conn.write([1, 0, pdu.bytesize + 1, 1].pack("nnnC") + pdu)
        conn.close
        request
    end

    def mbap_request(function, address, count)
        [1, 0, 6, 1, function, address, count].pack("nnnCCnn")
    end

    def write_request(address, values)
        pdu = ([16, address, values.size, values.size * 2] + values)
              .pack("CnnCn*")
        [1, 0, pdu.bytesize + 1, 1].pack("nnnC") + pdu
    end
end
