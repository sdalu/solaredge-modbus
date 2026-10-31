# frozen_string_literal: true

module SolarEdge
    module Modbus
        # A device an inverter can have several of, each one's registers
        # at its own offset from the first's: the class supplies
        # BASE_REGISTERS (the first's) and OFFSETS (one per device).
        module Numbered
            # 1 for the first.
            attr_reader :number

            def initialize(number:, **)
                unless (1..self.class::OFFSETS.size).cover?(number)
                    raise ArgumentError, "no #{self.class.name} #{number}"
                end
                super(**)
                @number = number
            end

            def registers
                base = self.class::BASE_REGISTERS
                @registers ||= base.transform_values do |reg|
                    reg.with(address: reg.address + offset)
                end
            end

            private

            def offset = self.class::OFFSETS[@number - 1]
        end
    end
end
