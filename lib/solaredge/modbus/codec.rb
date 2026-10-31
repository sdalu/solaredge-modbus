# frozen_string_literal: true

require "solaredge/modbus/error"

module SolarEdge
    module Modbus
        # Decodes/encodes one register value from/to a run of raw 16-bit
        # Modbus words. Each register's two bytes are big-endian
        # (standard Modbus); wordorder only says which register comes
        # first in a 32- or 64-bit value, and strings and 16-bit values
        # ignore it. A register holding SunSpec's "not implemented"
        # value decodes to nil.
        module Codec
            # SunSpec's "not implemented" values, as bit patterns: a
            # signed register is compared by its raw bits (int16 0x8000,
            # not -32768). Floats have none here: theirs are NaN
            # patterns, and any NaN counts.
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
            # read, whatever the table's length (battery event_log is a
            # uint16 over 2).
            WIDTHS = { uint16: 1, int16: 1, scale: 1, uint32: 2, acc32: 2,
                       int32: 2, float32: 2, sefloat: 2, uint64: 4 }.freeze

            # What each integer dtype can hold; encode refuses anything
            # else rather than wrapping it.
            RANGES = { uint16: 0..0xffff, int16: -0x8000..0x7fff,
                       scale: -0x8000..0x7fff, uint32: 0..0xffffffff,
                       int32: -0x80000000..0x7fffffff,
                       uint64: 0..0xffffffffffffffff }.freeze

            FLOAT32_MAX = 3.4028234663852886e38

            # An accumulator is read-only.
            ENCODE_FORMATS = FORMATS.except(:acc32).freeze

            module_function

            # An Integer, a Float or a String by dtype; nil when not
            # implemented.
            def decode(registers, dtype, wordorder)
                bytes = bytes_of(registers, dtype, wordorder)
                return if not_implemented?(bytes, dtype)
                raw_value(bytes, dtype)
            end

            # length: the register's, if the words must fit it; a string
            # is then padded with NULs to it.
            def encode(value, dtype, wordorder, length: nil)
                words = encode_words(value, dtype, wordorder)
                return words unless length
                if words.size > length
                    raise Error, "solaredge: #{words.size} registers of " \
                                 "#{dtype} for a #{length}-register field"
                end
                dtype == :string ? words + ([0] * (length - words.size)) : words
            end

            def encode_words(value, dtype, wordorder)
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

            # UTF-8 with invalid bytes dropped, NULs and trailing
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

            # The bytes as they are, an odd count padded with a NUL.
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

            # Any real number, infinities and NaN included, short of a
            # finite value past float32's range.
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
