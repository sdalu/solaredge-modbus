# frozen_string_literal: true

module SolarEdge
    module Modbus
        # A SolarEdge inverter over Modbus TCP: Registers::Inverter's
        # table (register-for-register from __init__.py:487-567 of
        # nmakel/solaredge_modbus @fd3ce7a; see modbus.rb for the
        # commit), plus #meters and #batteries discovery
        # (__init__.py:583-591).
        class Inverter < Device
            REGISTERS     = Registers::Inverter::REGISTERS
            LITTLE_ENDIAN = Registers::Inverter::LITTLE_ENDIAN

            # __init__.py:583-586: a meter is present when its probe
            # register (its c_sunspec_did) holds a nonzero value. A
            # probe the device refuses or leaves unimplemented is nil:
            # no meter. A connection failure raises.
            def meters
                found(:meter) { |v| v&.nonzero? }.to_h do |i|
                    [:"Meter#{i + 1}", Meter.new(parent: self, offset: i)]
                end
            end

            # __init__.py:588-591: present unless the probe holds 255,
            # or is nil as for #meters. (Upstream counts a failed or
            # unimplemented probe as a battery.)
            def batteries
                found(:battery) { |v| v && v != 255 }.to_h do |i|
                    [:"Battery#{i + 1}", Battery.new(parent: self, offset: i)]
                end
            end

            private

            def found(kind)
                dids(kind).each_index.select { |i| yield probe(kind, i) }
            end

            def dids(kind)
                if kind == :meter
                    Registers::Inverter::METER_DIDS
                else
                    Registers::Inverter::BATTERY_DIDS
                end
            end

            # nil when the device has no such register.
            def probe(kind, index)
                raw = read_raw(dids(kind)[index], 1, :holding)
                Codec.decode(raw, :uint16, :int, WORDORDER)
            rescue ModbusException
                nil
            end
        end
    end
end
