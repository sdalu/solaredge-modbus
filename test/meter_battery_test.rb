# frozen_string_literal: true

require "test_helper"

# Shared by this file's test classes: answers from a register image
# (address => raw 16-bit word) built in each test, never a socket.
class SolarEdgeFakeTransport
    def initialize(image)
        @image = image
        @connected = false
    end

    def connected? = @connected
    def connect = @connected = true
    def close = @connected = false

    def read_registers(_type, _unit, address, length)
        (address...(address + length)).map { |a| @image.fetch(a) }
    end
end

# Meter: meter 1's table, the others at Meter::OFFSETS from it.
class SolarEdgeMeterTest < Minitest::Test
    Modbus = SolarEdge::Modbus

    def meter(number, image)
        Modbus::Meter.new(number:, transport: SolarEdgeFakeTransport.new(image))
    end

    def test_meter_1_is_the_unshifted_table
        m = meter(1, 0x9d0e => 500)
        assert_equal 500, m.read(:power)
        assert_equal 1, m.number
    end

    # power: 0x9d0e + 0xae.
    def test_meter_2_shifts_every_address_by_0xae
        assert_equal 1200, meter(2, 0x9dbc => 1200).read(:power)
    end

    def test_a_meter_number_out_of_range_is_refused
        assert_raises(ArgumentError) { meter(0, {}) }
        assert_raises(ArgumentError) { meter(4, {}) }
    end

    def test_a_meter_number_must_be_an_integer
        assert_raises(ArgumentError) { meter(1.5, {}) }
        assert_raises(ArgumentError) { meter("1", {}) }
    end
end

# Battery: battery 1's table, the other at 0x100; low word first.
class SolarEdgeBatteryTest < Minitest::Test
    Modbus = SolarEdge::Modbus

    def battery(number, image)
        Modbus::Battery.new(number:,
                            transport: SolarEdgeFakeTransport.new(image))
    end

    # rated_energy (0xe142, sefloat) = 25.0, IEEE 754 0x41c80000, its
    # low word first on the wire.
    def test_a_32bit_value_has_its_low_word_first
        assert_in_delta 25.0, battery(1, 0xe142 => 0, 0xe143 => 0x41c8)
            .read(:rated_energy)
    end

    def test_battery_2_shifts_every_address_by_0x100
        assert_in_delta 25.0, battery(2, 0xe242 => 0, 0xe243 => 0x41c8)
            .read(:rated_energy)
    end

    def test_strings_ignore_the_wordorder
        regs = "LG Chem".b.ljust(32, "\x00").unpack("n*")
        image = regs.each_with_index.to_h { |w, i| [0xe100 + i, w] }
        assert_equal "LG Chem", battery(1, image).read(:c_manufacturer)
    end

    # event_log is a uint16 over two registers: its first. In read_all
    # the next register, event_log_internal, is read at its own address.
    def test_event_logs_read_their_own_first_register
        image = (0xe100..0xe193).to_h { [it, 0] }
        image.merge!(0xe18a => 1, 0xe18b => 2, 0xe191 => 17, 0xe192 => 34)
        b = battery(1, image)
        assert_equal 1, b.read(:event_log)
        all = b.read_all
        assert_equal [1, 34], all.values_at(:event_log, :event_log_internal)
    end

    def test_a_battery_number_out_of_range_is_refused
        assert_raises(ArgumentError) { battery(3, {}) }
    end
end

# StorEdge: one table, low word first.
class SolarEdgeStorEdgeTest < Minitest::Test
    def test_reads_a_setting
        storedge = SolarEdge::Modbus::StorEdge.new(
            transport: SolarEdgeFakeTransport.new(0xe000 => 1)
        )
        assert_equal 1, storedge.read(:export_control_mode)
    end
end
