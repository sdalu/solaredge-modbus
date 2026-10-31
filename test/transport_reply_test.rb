# frozen_string_literal: true

require "socket"

require "support/loopback_device"
require "test_helper"

# Replies Transport must refuse, each from a loopback device on
# 127.0.0.1 (never the network): late, cut short, stalled, for another
# request, or malformed. Each is an Error and closes the connection, so
# nothing left on the socket is read as a later answer.
class SolarEdgeTransportReplyTest < Minitest::Test
    Transport = SolarEdge::Modbus::Transport
    Error     = SolarEdge::Modbus::Error

    include LoopbackDevice

    def test_a_late_reply_is_not_taken_for_the_next_request
        late = lambda do |conn, request|
            sleep 0.4
            conn.write(reply(request, read_pdu([0xaaaa])))
        end
        device(late, answer(read_pdu([7]))) do |transport|
            assert_raises(Error) { transport.read_registers(:holding, 1, 0, 1) }
            refute_predicate transport, :connected?
            assert_equal [7], transport.read_registers(:holding, 1, 1, 1)
        end
    end

    def test_a_reply_stalled_mid_header_times_out
        stall = lambda do |conn, _request|
            conn.write("\x00\x01\x00")
            sleep 1
        end
        device(stall) do |transport|
            started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
            assert_refused(transport, /timed out/)
            waited = Process.clock_gettime(Process::CLOCK_MONOTONIC) - started
            assert_operator waited, :<, 0.8
        end
    end

    def test_a_reply_cut_short_raises_and_closes
        cut = ->(conn, _request) { conn.write("\x00\x01\x00") }
        device(cut) { |transport| assert_refused(transport, /closed/) }
    end

    def test_a_silent_device_times_out
        device(->(_conn, _request) { sleep 0.5 }) do |transport|
            assert_refused(transport, /timed out/)
        end
    end

    # An exception reply is a whole answer: the next request goes on
    # the same connection.
    def test_an_exception_reply_keeps_the_connection
        refused = "\x83\x02"
        device(answer_each(refused, read_pdu([7]))) do |transport|
            assert_raises(SolarEdge::Modbus::ModbusException) do
                read_one(transport)
            end
            assert_predicate transport, :connected?
            assert_equal [7], read_one(transport)
        end
    end

    def test_a_reply_to_another_transaction_is_refused
        device(answer(read_pdu([7]), tid: 99)) do |transport|
            assert_refused(transport, /reply 99/)
        end
    end

    def test_a_reply_without_byte_count_is_refused
        device(answer("\x03")) do |transport|
            assert_refused(transport, /bytes for/)
        end
    end

    def test_a_byte_count_disagreeing_with_the_request_is_refused
        device(answer("\x03\x03\x12\x34\x56")) do |transport|
            assert_refused(transport, /bytes for/)
        end
    end

    def test_another_function_is_not_reported_as_an_exception
        device(answer("\x04\x02\x00\x07")) do |transport|
            assert_refused(transport, /function 4/)
        end
    end

    def test_a_write_echoing_another_address_is_refused
        device(answer([16, 0x21, 1].pack("Cnn"))) do |transport|
            assert_raises(Error) { transport.write_registers(1, 0x20, [9]) }
        end
    end

    def test_connect_twice_keeps_one_socket
        with_server do |server, port|
            transport = Transport.new("127.0.0.1", port)
            transport.connect
            transport.connect
            server.accept.close
            pending = server.accept_nonblock(exception: false)
            assert_equal :wait_readable, pending
            transport.close
        end
    end

    def test_device_read_raises_on_a_malformed_reply
        device(*[answer("\x03")] * 3) do |transport|
            inverter = SolarEdge::Modbus::Inverter.new(transport:,
                                                       retry_delays: [0, 0])
            assert_raises(Error) { inverter.read(:status) }
        end
    end

    private

    def read_one(transport) = transport.read_registers(:holding, 1, 0, 1)

    def assert_refused(transport, message)
        error = assert_raises(Error) { read_one(transport) }
        assert_match(message, error.message)
        refute_predicate transport, :connected?
    end
end
