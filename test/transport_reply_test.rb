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
end

# Replies that cross from one connection to the next, as a SolarEdge
# inverter hands the late reply to a timed-out request to whichever
# client connects next.
class SolarEdgeTransportLeftoverTest < Minitest::Test
    include LoopbackDevice

    Transport = SolarEdge::Modbus::Transport

    # Draws `value` as the first transaction id less one.
    Draw = Data.define(:value) do
        def rand(_) = value
    end

    # What a SolarEdge inverter does: a late reply to a request that
    # timed out on another connection is written into the next one,
    # here before that connection's first request, and with the very
    # transaction id that request will carry. It must not be taken.
    def test_a_leftover_waiting_before_the_request_is_discarded
        with_server do |server, port|
            transport = Transport.new("127.0.0.1", port, random: Draw.new(0))
            written = Queue.new
            thread = Thread.new { leftover_then_answer(server, written) }
            transport.connect
            written.pop
            assert_equal [7], read_one(transport)
            thread.join(2)
        end
    end

    # A reply to another transaction is not ours: skipped, and ours
    # still taken when it follows.
    def test_a_reply_to_another_transaction_is_skipped
        stale_then_ours = lambda do |conn, request|
            conn.write(reply(request, read_pdu([0xdead]).b, tid: 99) +
                       reply(request, read_pdu([7]).b))
        end
        device(stale_then_ours) do |transport|
            assert_equal [7], read_one(transport)
        end
    end

    def test_only_replies_to_other_transactions_time_out
        foreign = lambda do |conn, request|
            conn.write(reply(request, read_pdu([7]).b, tid: 99))
            sleep 0.5
        end
        device(foreign) { |transport| assert_refused(transport, /timed out/) }
    end

    def test_each_connection_draws_its_first_transaction_id
        assert_equal [42, 1000], first_tids(41, 999)
    end

    private

    # Sends a reply for transaction 1 (the id the client's first request
    # will carry) on accepting, signals, then answers the real request.
    def leftover_then_answer(server, written)
        conn = server.accept
        conn.write([1, 0, 4 + 1, 1].pack("nnnC") + read_pdu([0xdead]))
        sleep 0.05
        written << true
        request = conn.readpartial(1024)
        conn.write(reply(request, read_pdu([7]).b))
    ensure
        conn&.close
    end

    # The transaction id of the first request of one connection per
    # draw.
    def first_tids(*draws)
        seen = Queue.new
        with_server do |server, port|
            thread = Thread.new { serve_recording(server, draws.size, seen) }
            draws.each { first_read(port, it) }
            thread.join(2)
        end
        Array.new(draws.size) { seen.pop }
    end

    def serve_recording(server, count, seen)
        record = lambda do |conn, request|
            seen << request.unpack1("n")
            conn.write(reply(request, read_pdu([7]).b))
        end
        count.times { handle(server.accept, record) }
    end

    def first_read(port, draw)
        transport = Transport.new("127.0.0.1", port, random: Draw.new(draw))
        transport.read_registers(:holding, 1, 0, 1)
        transport.close
    end
end
