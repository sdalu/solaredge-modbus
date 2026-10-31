# frozen_string_literal: true

require "test_helper"

# Device's generic machinery (__init__.py:189-458 of nmakel/
# solaredge_modbus @fd3ce7a; see modbus.rb): read, batched read_all,
# write, retries. Exercised through a tiny made-up register table
# (constructed here, not from any real device, to keep the fixtures
# small) over a fake transport that never opens a socket; Inverter/
# Meter/Battery/StorEdge's own real tables are exercised in their own
# test files.
class SolarEdgeDeviceTest < Minitest::Test
    Modbus   = SolarEdge::Modbus
    Register = Modbus::Register
    Error    = Modbus::Error

    # Two batches: batch 1 is one uint16 at 0x10; batch 2 is a uint16
    # at 0x20 and an int16 right after it at 0x21 -- read_all should
    # make exactly one Modbus request per batch, not per register.
    class Toy < SolarEdge::Modbus::Device
        REGISTERS = {
            a: Register.new(address: 0x10, length: 1, rtype: :holding,
                            dtype: :uint16, vtype: :int, batch: 1),
            b: Register.new(address: 0x20, length: 1, rtype: :holding,
                            dtype: :uint16, vtype: :int, batch: 2),
            c: Register.new(address: 0x21, length: 1, rtype: :holding,
                            dtype: :int16, vtype: :int, batch: 2)
        }.freeze
    end

    # Answers from a register image (address => raw 16-bit word) built
    # in the test, never a socket; can be told to fail its next N reads
    # to exercise Device's retry loop.
    class FakeTransport
        attr_reader :writes, :reads

        def initialize(image)
            @image = image
            @writes = []
            @reads = []
            @connected = false
            @fail = 0
        end

        def connected? = @connected
        def connect = @connected = true
        def close = @connected = false

        def read_registers(_rtype, _unit, address, length)
            @reads << [address, length]
            raise Error, "solaredge: simulated failure" if consume_failure?
            raise Modbus::ModbusException.new(2, 3) if @refused == address
            (address...(address + length)).map { |a| @image.fetch(a) }
        end

        # Named after Transport#write_registers, the interface Device
        # expects, not a predicate.
        # rubocop:disable-next Naming/PredicateMethod
        def write_registers(_unit, address, values)
            @writes << [address, values]
            true
        end

        def fail_next(count) = @fail = count
        def refuse(address) = @refused = address

        private

        def consume_failure?
            return false unless @fail.positive?
            @fail -= 1
            true
        end
    end

    def setup
        @image = { 0x10 => 7, 0x20 => 42, 0x21 => 0xffff }
        @transport = FakeTransport.new(@image)
        @device = Toy.new(transport: @transport)
    end

    def test_read_decodes_one_register
        assert_equal 7, @device.read(:a)
    end

    def test_read_refuses_an_unknown_key
        assert_raises(Error) { @device.read(:nope) }
    end

    def test_read_all_batches_by_batch_number_not_by_register
        assert_equal({ a: 7, b: 42, c: -1 }, @device.read_all)
        assert_equal [[0x10, 1], [0x20, 2]], @transport.reads
    end

    def test_read_retries_within_budget_then_succeeds
        @transport.fail_next(2)
        assert_equal 7, @device.read(:a)
    end

    def test_read_raises_once_the_retry_budget_is_spent
        @transport.fail_next(10)
        assert_raises(Error) { @device.read(:a) }
        assert_equal 3, @transport.reads.size
    end

    # The device's own refusal is its answer: no second try.
    def test_read_raises_a_refusal_without_retrying
        @transport.refuse(0x10)
        assert_raises(Modbus::ModbusException) { @device.read(:a) }
        assert_equal 1, @transport.reads.size
    end

    def test_read_all_leaves_out_a_batch_the_device_refuses
        @transport.refuse(0x20)
        assert_equal({ a: 7 }, @device.read_all)
    end

    def test_read_all_raises_when_a_batch_cannot_be_read
        @transport.fail_next(10)
        assert_raises(Error) { @device.read_all }
    end

    def test_write_encodes_and_calls_the_transport
        assert @device.write(:a, 99)
        assert_equal [[0x10, [99]]], @transport.writes
    end

    def test_write_refuses_an_unknown_key
        assert_raises(Error) { @device.write(:nope, 1) }
        assert_empty @transport.writes
    end

    def test_connects_on_first_read_and_stays_until_disconnect
        refute_predicate @device, :connected?
        @device.read(:a)
        @device.read(:b)
        assert_predicate @device, :connected?
        @device.disconnect
        refute_predicate @device, :connected?
    end

    def test_a_parent_shares_its_transport_and_unit
        child = Toy.new(parent: @device)
        assert_same @transport, child.transport
        assert_equal @device.unit, child.unit
    end
end
