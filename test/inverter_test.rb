# frozen_string_literal: true

require "test_helper"

# Inverter: Registers::Inverter's table (__init__.py:487-567 of nmakel/
# solaredge_modbus @fd3ce7a; see modbus.rb) and #meters/#batteries
# discovery (__init__.py:583-591). The register image below is built
# address by address in the test -- constructed, not recorded from any
# device -- over a fake transport that never opens a socket.
class SolarEdgeInverterTest < Minitest::Test
    Modbus = SolarEdge::Modbus
    Error  = Modbus::Error

    # Answers from a register image (address => raw 16-bit word);
    # an address missing from the image raises, simulating a device
    # that refuses or times out on that register.
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

        def read_registers(_rtype, _unit, address, length)
            @reads << [address, length]
            (address...(address + length)).map do |a|
                @image.fetch(a) { raise Error, "solaredge: no register #{a}" }
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

    def test_meters_skips_an_absent_meter
        assert_empty inverter({}).meters
    end

    # A nonzero probe (here 203, SunSpec DID 203: Wye 3P1N Three Phase
    # Meter -- Constants::SUNSPEC_DID[:wye_three_phase_meter]) means
    # the meter is attached; Meter2's addresses carry its instance
    # offset (Constants::METER_REGISTER_OFFSETS[1] == 0xae).
    def test_meters_finds_an_attached_meter_and_offsets_its_addresses
        inv = inverter(0x9cfc => 0, 0x9daa => 203, 0x9e58 => 0)
        meters = inv.meters
        assert_equal [:Meter2], meters.keys
        base = Modbus::Registers::Meter::REGISTERS.fetch(:c_manufacturer)
        offset = Modbus::Constants::METER_REGISTER_OFFSETS[1]
        meter2 = meters.fetch(:Meter2).registers.fetch(:c_manufacturer)
        assert_equal base.address + offset, meter2.address
    end

    # Meter 3's probe is its c_sunspec_did, 0x9cfc + 0x15c (upstream
    # probes one past it).
    def test_meters_probes_meter3_at_its_sunspec_did
        inv = inverter(0x9cfc => 0, 0x9daa => 0, 0x9e58 => 203)
        assert_equal [:Meter3], inv.meters.keys
    end

    # A probe that cannot be read (its address absent from the image)
    # is no battery; upstream counts it as one.
    def test_batteries_skips_a_failed_probe
        assert_empty inverter({}).batteries
    end

    def test_batteries_excludes_the_sentinel255
        inv = inverter(0xe140 => 255, 0xe240 => 1)
        assert_equal [:Battery2], inv.batteries.keys
    end

    def test_discovered_devices_share_the_inverters_transport
        inv = inverter(0x9cfc => 203)
        meter = inv.meters.fetch(:Meter1)
        assert_same inv.transport, meter.transport
    end
end
