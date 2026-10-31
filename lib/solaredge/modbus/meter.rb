# frozen_string_literal: true

module SolarEdge
    module Modbus
        # One of an inverter's up to three meters (number 1 to 3). Built
        # by Inverter#meters, sharing the inverter's connection, or
        # directly with `parent:`, or `host:` and `port:` for a
        # connection of its own.
        class Meter < Device
            include Numbered

            BASE_REGISTERS = Registers::Meter::REGISTERS
            OFFSETS = [0x0, 0xae, 0x15c].freeze
        end
    end
end
