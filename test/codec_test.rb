# frozen_string_literal: true

require "test_helper"

# Codec decode/encode, checked register by register against
# __init__.py:297-349 of nmakel/solaredge_modbus @fd3ce7a
# (_encode_value/_decode_value) and the NOT_IMPLEMENTED sentinels at
# __init__.py:79-90. Byte strings below are derived (built register by
# register to match a documented decode/encode rule), not recorded
# from a device -- codec.rb never touches a socket.
class SolarEdgeCodecTest < Minitest::Test
    Codec = SolarEdge::Modbus::Codec
    Error = SolarEdge::Modbus::Error

    def test_uint16_decodes_and_flags_not_implemented
        assert_equal 1234, Codec.decode([1234], :uint16, :int, :big)
        assert_equal 0, Codec.decode([0xffff], :uint16, :int, :big)
    end

    def test_int16_and_its_scale_alias_decode_signed
        assert_equal(-1, Codec.decode([0xffff], :int16, :int, :big))
        assert_equal 1234, Codec.decode([1234], :scale, :int, :big)
    end

    # 0x8000 is the int16/scale NOT_IMPLEMENTED bit pattern -- as a
    # *signed* value that is -32768, which the raw-bits check (not the
    # signed value) must still catch.
    def test_int16_not_implemented_sentinel_is_the_bit_pattern
        assert_equal 0, Codec.decode([0x8000], :int16, :int, :big)
        assert_equal 0, Codec.decode([0x8000], :scale, :int, :big)
    end

    def test_uint32_and_acc32_share_their_decode_width
        assert_equal 70_000, Codec.decode([1, 4464], :uint32, :int, :big)
        assert_equal 70_000, Codec.decode([1, 4464], :acc32, :int, :big)
        assert_equal 0, Codec.decode([0xffff, 0xffff], :uint32, :int, :big)
        # ACC32's own sentinel is 0 (__init__.py:86), not 0xffffffff --
        # an inverter reporting exactly 0 Wh decodes as "not
        # implemented" too; that ambiguity is upstream's, kept as-is.
        assert_equal 0, Codec.decode([0, 0], :acc32, :int, :big)
    end

    def test_int32_decodes_signed_and_flags_its_own_sentinel
        assert_equal(-1, Codec.decode([0xffff, 0xffff], :int32, :int, :big))
        assert_equal 0, Codec.decode([0x8000, 0], :int32, :int, :big)
    end

    def test_uint64_decodes_and_flags_not_implemented
        assert_equal 1, Codec.decode([0, 0, 0, 1], :uint64, :int, :big)
        sentinel = [0xffff] * 4
        assert_equal 0, Codec.decode(sentinel, :uint64, :int, :big)
    end

    # README.md's own example (nmakel/solaredge_modbus @fd3ce7a,
    # fetched 2026-10-30): power_ac 21413 * 10**-1 = 2141.3W is reported
    # as 'Power: 2141.80W'; the float32 fixture below is independent of
    # that (IEEE 754 for 25.0 is 0x41c80000), used because it is exact.
    def test_float32_and_sefloat_decode_ieee754
        regs = [0x41c8, 0x0000]
        assert_in_delta 25.0, Codec.decode(regs, :float32, :float, :big)
        assert_in_delta 25.0, Codec.decode(regs, :sefloat, :float, :big)
    end

    # Both NOT_IMPLEMENTED bit patterns for these types (0x7fc00000 and
    # 0xffffffff) are themselves NaN float32 bit patterns -- "not
    # implemented" is decoded.nan?, not a table lookup (see codec.rb).
    def test_float_not_implemented_sentinels_are_both_nan
        assert_in_delta 0.0, Codec.decode([0x7fc0, 0], :float32, :float, :big)
        assert_in_delta 0.0, Codec.decode([0xffff, 0xffff], :sefloat,
                                          :float, :big)
    end

    def test_string_decodes_utf8_and_strips_nuls_and_trailing_space
        bytes = "#{"SunS".b}\x00\x00\x00\x00"
        regs = bytes.unpack("n*")
        assert_equal "SunS", Codec.decode(regs, :string, :str, :big)
    end

    # str(False) in Python literally is the text "False" --
    # __init__.py:342-347's vtype(False) coercion for a not-implemented
    # STRING register; kept as that exact quirk, not "fixed" to "".
    def test_string_not_implemented_coerces_to_the_word_false
        regs = "\x00\x00\x00\x00".unpack("n*")
        assert_equal "False", Codec.decode(regs, :string, :str, :big)
    end

    # wordorder LITTLE reverses which register is most significant
    # (__init__.py:271, "wordorder = Endian.LITTLE if address in
    # self.little_endian_registers"); 70000 big-endian as [1, 4464]
    # becomes [4464, 1] little-endian.
    def test_wordorder_little_reverses_the_registers
        assert_equal 70_000, Codec.decode([4464, 1], :uint32, :int, :little)
    end

    def test_encode_round_trips_through_decode
        %i[uint16 int16 uint32 int32 uint64].each do |dtype|
            registers = Codec.encode(42, dtype, :big)
            assert_equal 42, Codec.decode(registers, dtype, :int, :big)
        end
    end

    def test_encode_float32_round_trips
        registers = Codec.encode(25.0, :float32, :big)
        assert_in_delta 25.0, Codec.decode(registers, :float32, :float, :big)
    end

    # _encode_value's if/elif chain (__init__.py:300-319) has no ACC32
    # branch -- encoding one falls to "else: raise NotImplementedError".
    def test_encode_refuses_acc32
        assert_raises(Error) { Codec.encode(1, :acc32, :big) }
    end
end
