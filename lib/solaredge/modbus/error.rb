# frozen_string_literal: true

module SolarEdge
    module Modbus
        class Error < StandardError; end

        # The device's own exception reply.
        class ModbusException < Error
            # Codes by which the device refuses the request itself:
            # illegal function, data address or data value. Asking again
            # gets the same answer. Any other code (busy, device failure,
            # gateway) may clear.
            REFUSALS = [1, 2, 3].freeze

            attr_reader :code, :function

            def initialize(code, function)
                @code = code
                @function = function
                super("solaredge: Modbus exception #{code} on function " \
                      "#{function}")
            end

            def refusal? = REFUSALS.include?(code)
        end
    end
end
