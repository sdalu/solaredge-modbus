# frozen_string_literal: true

require "test_helper"

# Inverter: its table and #meters/#batteries discovery, over a register
# image built address by address in each test (not recorded from a
# device) and a fake transport that never opens a socket.
class SolarEdgeInverterTest < Minitest::Test
    Modbus = SolarEdge::Modbus
    Error  = Modbus::Error

    # Answers from a register image (address => raw 16-bit word);
    # an address missing from the image is refused with an exception
    # reply (code 2, illegal data address), as a device without that
    # register answers.
    class FakeTransport
        attr_reader :reads

        def initialize(image)
            @image = image
            @reads = []
            @connected = false
        end

        def connected? = @connected
        def connect = @connected = true
        def close = @connected = false

        def read_registers(_type, _unit, address, length)
            @reads << [address, length]
            (address...(address + length)).map do |a|
                @image.fetch(a) { raise Modbus::ModbusException.new(2, 3) }
            end
        end
    end

    def inverter(image)
        Modbus::Inverter.new(transport: FakeTransport.new(image))
    end

    # power_ac 21413, scale -1 -> README.md's own worked example
    # (nmakel/solaredge_modbus @fd3ce7a, fetched 2026-10-30): "Power:
    # 2141.80W" -- actually 2141.3 once the scale is applied; the 2141
    # 80/100 in the README comes from rounding in its own display code,
    # not from the register values quoted alongside it (power_ac 21413,
    # power_ac_scale -1), which is what this fixture reproduces.
    def test_reads_status_and_power
        inv = inverter(0x9cab => 4, 0x9c93 => 21_413, 0x9c94 => 0xffff)
        assert_equal 4, inv.read(:status)
        assert_equal 21_413, inv.read(:power_ac)
        # 0xffff is SCALE's own sentinel only via the signed bit
        # pattern 0x8000 -- 0xffff decodes as the ordinary int16 -1.
        assert_equal(-1, inv.read(:power_ac_scale))
    end

    # export_control_site_limit is a float32 with its low word first:
    # 1500.5 (0x44bb9000) comes back whole, not truncated to 1500.
    def test_a_float_register_reads_as_a_float
        inv = inverter(0xf702 => 0x9000, 0xf703 => 0x44bb)
        assert_in_delta 1500.5, inv.read(:export_control_site_limit)
    end

    def test_meters_skips_an_absent_meter
        assert_empty inverter({}).meters
    end

    # A meter is attached when its c_sunspec_did holds a model id (203,
    # a wye three-phase meter); meter 2's addresses are offset by 0xae.
    def test_meters_finds_an_attached_meter_and_offsets_its_addresses
        meters = inverter(0x9cfc => 0, 0x9daa => 203, 0x9e58 => 0).meters
        assert_equal [2], meters.map(&:number)
        base = Modbus::Registers::Meter::REGISTERS.fetch(:c_manufacturer)
        assert_equal base.address + 0xae,
                     meters.first.registers.fetch(:c_manufacturer).address
    end

    # Meter 3's probe is its c_sunspec_did, 0x9cfc + 0x15c.
    def test_meters_probes_meter3_at_its_sunspec_did
        inv = inverter(0x9cfc => 0, 0x9daa => 0, 0x9e58 => 203)
        assert_equal [3], inv.meters.map(&:number)
    end

    # A probe the device refuses (its address absent from the image)
    # or leaves unimplemented is no battery.
    def test_batteries_skips_a_refused_or_unimplemented_probe
        assert_empty inverter({}).batteries
        assert_empty inverter(0xe140 => 0xffff, 0xe240 => 0xffff).batteries
    end

    def test_batteries_excludes_the_sentinel255
        inv = inverter(0xe140 => 255, 0xe240 => 1)
        assert_equal [2], inv.batteries.map(&:number)
    end

    def test_discovered_devices_share_the_inverters_transport
        inv = inverter(0x9cfc => 203)
        assert_same inv.transport, inv.meters.first.transport
    end
end
