# frozen_string_literal: true

require "solaredge/modbus/battery"
require "solaredge/modbus/device"
require "solaredge/modbus/meter"
require "solaredge/modbus/registers/inverter"

module SolarEdge
    module Modbus
        # A SolarEdge inverter, and the meters and batteries attached to
        # it.
        class Inverter < Device
            REGISTERS     = Registers::Inverter::REGISTERS
            LITTLE_ENDIAN = Registers::Inverter::LITTLE_ENDIAN

            # The meters present: those whose c_sunspec_did holds a
            # model id. A connection failure raises.
            def meters
                attached(Meter, :c_sunspec_did) { it&.nonzero? }
            end

            # The batteries present: those whose c_deviceaddress holds
            # something other than 255.
            def batteries
                attached(Battery, :c_deviceaddress) { it && it != 255 }
            end

            private

            def attached(kind, probe)
                (1..kind::OFFSETS.size).filter_map do |number|
                    device = kind.new(parent: self, number:)
                    device if yield probe(device, probe)
                end
            end

            # nil when the device refuses the register: none there.
            def probe(device, key)
                device.read(key)
            rescue ModbusException
                nil
            end
        end
    end
end
