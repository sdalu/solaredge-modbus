# frozen_string_literal: true

module SolarEdge
    # SolarEdge inverters, and the meters, batteries and StorEdge
    # settings attached to them, read and written over Modbus TCP.
    # Grown from nmakel/solaredge_modbus at commit fd3ce7a (2025-01-08),
    # whose register tables it carries; an "__init__.py:N" in a comment
    # points into that commit's src/solaredge_modbus/__init__.py.
    module Modbus
        class Error < StandardError; end

        # The device's own refusal (an exception reply): it does not
        # have those registers, or will not take that value.
        class ModbusException < Error
            attr_reader :code, :function

            def initialize(code, function)
                @code = code
                @function = function
                super("solaredge: Modbus exception #{code} on function " \
                      "#{function}")
            end
        end
    end
end

require "solaredge/modbus/version"
require "solaredge/modbus/codec"
require "solaredge/modbus/register"
require "solaredge/modbus/constants"
require "solaredge/modbus/registers/inverter"
require "solaredge/modbus/registers/meter"
require "solaredge/modbus/registers/battery"
require "solaredge/modbus/registers/storedge"
require "solaredge/modbus/transport"
require "solaredge/modbus/frame"
require "solaredge/modbus/device"
require "solaredge/modbus/numbered"
require "solaredge/modbus/inverter"
require "solaredge/modbus/meter"
require "solaredge/modbus/battery"
require "solaredge/modbus/storedge"
