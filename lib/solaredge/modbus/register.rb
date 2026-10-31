# frozen_string_literal: true

module SolarEdge
    module Modbus
        # One row of a device's register table: upstream's own register
        # tuple (address, length, register type, data type, target
        # type, label, unit, batch -- __init__.py's per-device
        # `self.registers` dicts), minus the label/unit text, which this
        # port does not use. rtype is always :holding in the ported
        # tables (registerType.INPUT, __init__.py:62-63, is declared
        # upstream but never assigned to a register).
        #
        #   address  Integer, the Modbus register address (0-based,
        #            matching the raw wire offset -- see Transport).
        #   length   Integer, width in 16-bit registers.
        #   rtype    :holding or :input.
        #   dtype    :uint16, :uint32, :uint64, :int16, :scale, :acc32,
        #            :float32, :sefloat, :int32 or :string (Codec).
        #   vtype    :int, :float or :str -- the decoded Ruby type.
        #   batch    Integer, upstream's read_all() grouping (registers
        #            sharing a batch are read in one Modbus request).
        Register = Data.define(:address, :length, :rtype, :dtype, :vtype,
                               :batch)
    end
end
