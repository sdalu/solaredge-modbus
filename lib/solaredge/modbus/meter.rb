# frozen_string_literal: true

module SolarEdge
    module Modbus
        # One of an inverter's up to three meters, __init__.py:593-692
        # of nmakel/solaredge_modbus @fd3ce7a (see modbus.rb for the
        # commit): Registers::Meter's table with `offset` (0, 1 or 2,
        # matching Constants::METER_REGISTER_OFFSETS) added to every
        # address. Built via Inverter#meters, or directly with either
        # `parent:` (shares the inverter's connection, as upstream's own
        # `parent=` does) or `host:`/`port:` for a standalone connection.
        class Meter < Device
            def initialize(offset:, **)
                super(**)
                @offset = Constants::METER_REGISTER_OFFSETS.fetch(offset)
            end

            def registers
                @registers ||= base_registers.transform_values do |reg|
                    reg.with(address: reg.address + @offset)
                end
            end

            private

            def base_registers = Registers::Meter::REGISTERS
        end
    end
end
