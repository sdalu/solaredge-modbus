# frozen_string_literal: true

module SolarEdge
    module Modbus
        # Decodes/encodes one register value from/to a run of raw 16-bit
        # Modbus words, per __init__.py:297-349 of nmakel/
        # solaredge_modbus @fd3ce7a (_encode_value/_decode_value; see
        # modbus.rb for the commit) and the pymodbus 3.5 payload
        # coders it calls (upstream's setup.cfg pins pymodbus ~= 3.5.0).
        # byteorder is always big-endian (each register's own two bytes,
        # standard Modbus). wordorder only changes which register comes
        # first in a 32- or 64-bit value: pymodbus's 16-bit and string
        # coders never look at it.
        #
        # A register holding SunSpec's "not implemented" value decodes
        # to nil (upstream returns 0, 0.0 or "False", which a real zero
        # cannot be told from).
        module Codec
            # SunSpec's "not implemented" values, __init__.py:79-90, as
            # bit patterns: a signed register is compared by its raw
            # bits, so int16 0x8000 is caught. (Upstream compares the
            # signed value, -32768, with 0x8000 and never matches.)
            # Floats have none here: both of theirs are NaN patterns,
            # and any NaN counts.
            NOT_IMPLEMENTED = {
                uint16: 0xffff, uint32: 0xffffffff,
                uint64: 0xffffffffffffffff, int16: 0x8000, scale: 0x8000,
                acc32: 0x00000000, int32: 0x80000000
            }.freeze

            FLOAT_TYPES = %i[float32 sefloat].freeze

            # Array#pack / String#unpack1 directives: big-endian 16/32/
            # 64-bit (un)signed and the IEEE 754 single ("g" is
            # network-order single-precision float).
            FORMATS = { uint16: "n", int16: "s>", scale: "s>", uint32: "N",
                        acc32: "N", int32: "l>", uint64: "Q>",
                        float32: "g", sefloat: "g" }.freeze

            # The same widths, always unsigned: the raw bits that
            # NOT_IMPLEMENTED is compared with.
            BITS = { uint16: "n", int16: "n", scale: "n", uint32: "N",
                     acc32: "N", int32: "N", uint64: "Q>" }.freeze

            # Registers each dtype decodes, from the start of what was
            # read: pymodbus's decoders take their own width, whatever
            # the table's length (battery event_log is a uint16 over 2).
            WIDTHS = { uint16: 1, int16: 1, scale: 1, uint32: 2, acc32: 2,
                       int32: 2, float32: 2, sefloat: 2, uint64: 4 }.freeze

            # What struct.pack accepts for each integer format; out of
            # range, it raises rather than wrapping.
            RANGES = { uint16: 0..0xffff, int16: -0x8000..0x7fff,
                       scale: -0x8000..0x7fff, uint32: 0..0xffffffff,
                       int32: -0x80000000..0x7fffffff,
                       uint64: 0..0xffffffffffffffff }.freeze

            FLOAT32_MAX = 3.4028234663852886e38

            # _encode_value's if/elif chain, __init__.py:300-319: no
            # ACC32 branch there (an accumulator is read-only in
            # practice), so FORMATS minus :acc32.
            ENCODE_FORMATS = FORMATS.except(:acc32).freeze

            module_function

            def decode(registers, dtype, vtype, wordorder)
                bytes = bytes_of(registers, dtype, wordorder)
                return if not_implemented?(bytes, dtype)
                cast(raw_value(bytes, dtype), vtype)
            end

            def encode(value, dtype, wordorder)
                return encode_string(value) if dtype == :string
                check_encodable(value, dtype)
                words = [value].pack(ENCODE_FORMATS.fetch(dtype)).unpack("n*")
                wordorder == :little ? words.reverse : words
            end

            def bytes_of(registers, dtype, wordorder)
                return registers.pack("n*") if dtype == :string
                words = registers.first(WIDTHS.fetch(dtype) { unknown(dtype) })
                words = words.reverse if wordorder == :little
                words.pack("n*")
            end

            def raw_value(bytes, dtype)
                return decode_string(bytes) if dtype == :string
                bytes.unpack1(FORMATS.fetch(dtype))
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
                return decode_string(bytes).empty? if dtype == :string
                bytes.unpack1(BITS.fetch(dtype)) == NOT_IMPLEMENTED[dtype]
            end

            def cast(raw, vtype)
                return raw.to_i if vtype == :int
                return raw.to_f if vtype == :float
                raw
            end

            # add_string packs the bytes as they are; to_registers pads
            # an odd count with a NUL.
            def encode_string(value)
                bytes = value.to_s.b
                bytes << "\x00" if bytes.bytesize.odd?
                bytes.unpack("n*")
            end

            def check_encodable(value, dtype)
                ENCODE_FORMATS.fetch(dtype) do
                    raise Error, "solaredge: cannot encode #{dtype}"
                end
                return check_float(value) if FLOAT_TYPES.include?(dtype)
                return if value.is_a?(Integer) && RANGES[dtype].cover?(value)
                raise Error, "solaredge: #{value.inspect} is not a #{dtype}"
            end

            # struct.pack("f") takes any real number and infinities, but
            # refuses a finite value past float32's range.
            def check_float(value)
                fits = value.is_a?(Numeric) && !value.is_a?(Complex) &&
                       !(value.finite? && value.abs > FLOAT32_MAX)
                raise Error, "solaredge: #{value.inspect} is not a float32" \
                    unless fits
            end

            def unknown(dtype)
                raise Error, "solaredge: unknown register type #{dtype}"
            end
        end
    end
end
