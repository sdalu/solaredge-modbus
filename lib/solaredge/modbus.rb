# frozen_string_literal: true

module SolarEdge
    # A Ruby port of nmakel/solaredge_modbus (github.com/nmakel/
    # solaredge_modbus), commit fd3ce7ae32a259ee371c672dac3bcd75bfe51258
    # (2025-01-08, "0.8.0-8-gfd3ce7a" per `git describe`): SolarEdge
    # inverters, meters, batteries and StorEdge settings, read and
    # written over Modbus TCP through SunSpec registers. Every
    # "__init__.py:N" in this library points into
    # src/solaredge_modbus/__init__.py at that commit.
    #
    # Modbus TCP framing (the MBAP header; function codes 3, 4 and 16,
    # the only ones pymodbus's ModbusTcpClient issues for this library's
    # reads and writes) is plain Ruby over an injectable Transport, so
    # nothing here needs a real socket to be tested. See Transport for
    # the framing sources.
    module Modbus
        class Error < StandardError; end
    end
end

require "solaredge/modbus/version"
require "solaredge/modbus/codec"
require "solaredge/modbus/register"
require "solaredge/modbus/constants"
require "solaredge/modbus/control_constants"
require "solaredge/modbus/registers/inverter"
require "solaredge/modbus/registers/meter"
require "solaredge/modbus/registers/battery"
require "solaredge/modbus/registers/storedge"
require "solaredge/modbus/transport"
require "solaredge/modbus/frame"
require "solaredge/modbus/device"
require "solaredge/modbus/inverter"
require "solaredge/modbus/meter"
require "solaredge/modbus/battery"
require "solaredge/modbus/storedge"
