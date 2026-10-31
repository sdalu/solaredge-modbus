# frozen_string_literal: true

require "test_helper"

# Shared by this file's three test classes: answers from a register
# image (address => raw 16-bit word) built in each test, never a
# socket.
class SolarEdgeFakeTransport
    def initialize(image)
        @image = image
        @connected = false
    end

    def connected? = @connected
    def connect = @connected = true
    def close = @connected = false

    def read_registers(_rtype, _unit, address, length)
        (address...(address + length)).map { |a| @image.fetch(a) }
    end
end

# Meter, __init__.py:593-692 of nmakel/solaredge_modbus @fd3ce7a (see
# modbus.rb): Registers::Meter's table with the instance offset
# added, wordorder BIG (Device's default, unchanged by Meter).
class SolarEdgeMeterTest < Minitest::Test
    Modbus = SolarEdge::Modbus

    def meter(offset, image)
        transport = SolarEdgeFakeTransport.new(image)
        Modbus::Meter.new(offset:, transport:)
    end

    # power, Meter2 (offset Constants::METER_REGISTER_OFFSETS[1] ==
    # 0xae): base address 0x9d0e + 0xae = 0x9dbc.
    def test_offset_1_shifts_every_address_by_0xae
        m = meter(1, 0x9dbc => 1200)
        assert_equal 1200, m.read(:power)
    end

    def test_an_offset_past_meter_3_is_refused
        assert_raises(IndexError) { meter(3, {}) }
    end

    def test_offset_0_is_the_unshifted_table
        m = meter(0, 0x9d0e => 500)
        assert_equal 500, m.read(:power)
    end
end

# Battery, __init__.py:719-763 (see modbus.rb): Registers::Battery's
# table with the instance offset added, wordorder LITTLE throughout
# (self.wordorder = Endian.LITTLE, __init__.py:723 -- the whole class,
# not just some registers, unlike Inverter's little_endian_registers).
class SolarEdgeBatteryTest < Minitest::Test
    Modbus = SolarEdge::Modbus

    # rated_energy (0xe142, sefloat, 2 registers) = 25.0 (IEEE 754
    # 0x41c80000). Wordorder LITTLE means the *wire* register order is
    # reversed from the natural big-endian [0x41c8, 0x0000], so the
    # fixture stores [0x0000, 0x41c8] at [0xe142, 0xe143].
    def test_wordorder_is_little_for_every_register
        transport = SolarEdgeFakeTransport.new(0xe142 => 0x0000,
                                               0xe143 => 0x41c8)
        battery = Modbus::Battery.new(offset: 0, transport:)
        assert_in_delta 25.0, battery.read(:rated_energy)
    end

    # Battery2: offset Constants::BATTERY_REGISTER_OFFSETS[1] == 0x100.
    def test_offset_1_shifts_every_address_by_0x100
        transport = SolarEdgeFakeTransport.new(0xe242 => 0x0000,
                                               0xe243 => 0x41c8)
        battery = Modbus::Battery.new(offset: 1, transport:)
        assert_in_delta 25.0, battery.read(:rated_energy)
    end

    def test_an_offset_past_battery_2_is_refused
        transport = SolarEdgeFakeTransport.new({})
        assert_raises(IndexError) do
            SolarEdge::Modbus::Battery.new(offset: 2, transport:)
        end
    end
end

# StorEdge, __init__.py:694-717 (see modbus.rb): no per-instance
# offset, wordorder LITTLE (self.wordorder = Endian.LITTLE,
# __init__.py:698).
class SolarEdgeStorEdgeTest < Minitest::Test
    Modbus = SolarEdge::Modbus

    def test_reads_a_setting_with_wordorder_little
        transport = SolarEdgeFakeTransport.new(0xe000 => 1)
        storedge = Modbus::StorEdge.new(transport:)
        assert_equal 1, storedge.read(:export_control_mode)
    end
end
