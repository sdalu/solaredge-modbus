# frozen_string_literal: true

module SolarEdge
    module Modbus
        # One of an inverter's up to two batteries (number 1 or 2), built
        # as a Meter is. Its 32- and 64-bit values put their low word
        # first.
        class Battery < Device
            include Numbered

            BASE_REGISTERS = Registers::Battery::REGISTERS
            OFFSETS = [0x0, 0x100].freeze
            WORDORDER = :little
        end
    end
end
