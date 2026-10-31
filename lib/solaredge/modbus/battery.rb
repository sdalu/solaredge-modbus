# frozen_string_literal: true

module SolarEdge
    module Modbus
        # One of an inverter's up to two batteries, __init__.py:719-763
        # of nmakel/solaredge_modbus @fd3ce7a (see modbus.rb for the
        # commit): Registers::Battery's table with `offset` (0 or 1,
        # matching Constants::BATTERY_REGISTER_OFFSETS) added to every
        # address, wordorder LITTLE (self.wordorder = Endian.LITTLE in
        # __init__.py:723; it orders the words of 32- and 64-bit values
        # only, see Codec). Built
        # via Inverter#batteries, or directly with `parent:` or
        # `host:`/`port:`.
        class Battery < Device
            WORDORDER = :little

            def initialize(offset:, **)
                super(**)
                @offset = Constants::BATTERY_REGISTER_OFFSETS.fetch(offset)
            end

            def registers
                @registers ||= base_registers.transform_values do |reg|
                    reg.with(address: reg.address + @offset)
                end
            end

            private

            def base_registers = Registers::Battery::REGISTERS
        end
    end
end
