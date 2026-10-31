# frozen_string_literal: true

module SolarEdge
    module Modbus
        # One row of a device's register table, as the tables write it:
        # [address, length, dtype, batch]. Every register is a holding
        # register.
        #
        #   address  Integer, the Modbus register address (0-based,
        #            matching the raw wire offset -- see Transport).
        #   length   Integer, width in 16-bit registers.
        #   dtype    :uint16, :uint32, :uint64, :int16, :scale, :acc32,
        #            :float32, :sefloat, :int32 or :string (Codec).
        #   batch    Integer: registers sharing a batch are read in one
        #            Modbus request by Device#read_all.
        Register = Data.define(:address, :length, :dtype, :batch)
    end
end
