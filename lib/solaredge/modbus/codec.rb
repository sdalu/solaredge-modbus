# frozen_string_literal: true

module SolarEdge
    module Modbus
        # Decodes/encodes one register value from/to a run of raw 16-bit
        # Modbus words, per __init__.py:297-349 of nmakel/
        # solaredge_modbus @fd3ce7a (_encode_value/_decode_value; see
        # modbus.rb for the commit). byteorder is always big-endian
        # there (each register's own two bytes, standard Modbus);
        # wordorder (big or little) only changes which register comes
        # first when a value spans several -- implemented here as
        # reversing the register list before packing/after unpacking.
        module Codec
            # SUNSPEC_NOTIMPLEMENTED, __init__.py:79-90. FLOAT32/SEFLOAT
            # are not listed: both decode via decode_32bit_float, and
            # their sentinels (0x7fc00000 and 0xffffffff) are each a NaN
            # bit pattern, so "not implemented" is simply decoded.nan?
            # (see not_implemented? below).
            NOT_IMPLEMENTED = {
                uint16: 0xffff, uint32: 0xffffffff,
                uint64: 0xffffffffffffffff, int16: 0x8000, scale: 0x8000,
                acc32: 0x00000000, int32: 0x80000000, string: ""
            }.freeze

            FLOAT_TYPES = %i[float32 sefloat].freeze

            # Array#pack / String#unpack1 directives: big-endian 16/32/
            # 64-bit (un)signed and the IEEE 754 single ("g" is
            # network-order single-precision float).
            FORMATS = { uint16: "n", int16: "s>", scale: "s>", uint32: "N",
                        acc32: "N", int32: "l>", uint64: "Q>",
                        float32: "g", sefloat: "g" }.freeze

            # The same widths, but always unsigned -- NOT_IMPLEMENTED's
            # sentinels are bit patterns (0x8000, 0x80000000...), so a
            # signed dtype (int16, scale, int32) must compare its raw
            # *bits*, not the value decode_value_signed already turned
            # negative, against them.
            UNSIGNED_FORMATS = { uint16: "n", int16: "n", scale: "n",
                                 uint32: "N", acc32: "N", int32: "N",
                                 uint64: "Q>" }.freeze

            # _encode_value's if/elif chain, __init__.py:300-319: no
            # ACC32 branch there (an accumulator is read-only in
            # practice), so FORMATS minus :acc32.
            ENCODE_FORMATS = FORMATS.except(:acc32).freeze

            module_function

            def decode(registers, dtype, vtype, wordorder)
                bytes = bytes_of(registers, wordorder)
                return coerce_false(vtype) if not_implemented?(bytes, dtype)
                cast(raw_value(bytes, dtype), vtype)
            end

            def encode(value, dtype, wordorder)
                bytes = raw_bytes(value, dtype)
                registers = bytes.unpack("n*")
                wordorder == :little ? registers.reverse : registers
            end

            def bytes_of(registers, wordorder)
                ordered = wordorder == :little ? registers.reverse : registers
                ordered.pack("n*")
            end

            def raw_value(bytes, dtype)
                return decode_string(bytes) if dtype == :string
                bytes.unpack1(FORMATS.fetch(dtype) do
                    raise Error, "solaredge: unknown register type #{dtype}"
                end)
            end

            # decode_string, __init__.py:339: utf-8, invalid bytes
            # dropped (Python's errors="ignore"), NULs and trailing
            # whitespace stripped.
            def decode_string(bytes)
                bytes.dup.force_encoding("UTF-8").scrub("")
                     .delete("\u0000").rstrip
            end

            def not_implemented?(bytes, dtype)
                return bytes.unpack1("g").nan? if FLOAT_TYPES.include?(dtype)
                return decode_string(bytes) == "" if dtype == :string
                bits = bytes.unpack1(UNSIGNED_FORMATS.fetch(dtype))
                bits == NOT_IMPLEMENTED.fetch(dtype)
            end

            # __init__.py:342-347: a not-implemented or NaN register
            # becomes vtype(False) -- 0 for int, 0.0 for float, and (as
            # Python's str(False) literally reads) the text "False" for
            # a string register.
            def coerce_false(vtype)
                { int: 0, float: 0.0, str: "False" }.fetch(vtype)
            end

            def cast(raw, vtype)
                return raw.to_i if vtype == :int
                return raw.to_f if vtype == :float
                raw
            end

            def raw_bytes(value, dtype)
                return value.to_s.b if dtype == :string
                [value].pack(ENCODE_FORMATS.fetch(dtype) do
                    raise Error, "solaredge: cannot encode #{dtype}"
                end)
            end
        end
    end
end
