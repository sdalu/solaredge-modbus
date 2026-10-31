# frozen_string_literal: true

module SolarEdge
    module Modbus
        # An inverter's StorEdge (battery system) settings. Its 32-bit
        # values put their low word first.
        class StorEdge < Device
            REGISTERS = Registers::StorEdge::REGISTERS
            WORDORDER = :little
        end
    end
end
