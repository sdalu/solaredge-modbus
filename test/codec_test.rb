# frozen_string_literal: true

require "test_helper"

# Codec decode/encode, one dtype at a time. The registers below are
# built from each type's encoding, not recorded from a device.
class SolarEdgeCodecTest < Minitest::Test
    Codec = SolarEdge::Modbus::Codec
    Error = SolarEdge::Modbus::Error

    def test_uint16_decodes_and_flags_not_implemented
        assert_equal 1234, Codec.decode([1234], :uint16, :big)
        assert_nil Codec.decode([0xffff], :uint16, :big)
    end

    def test_int16_and_its_scale_alias_decode_signed
        assert_equal(-1, Codec.decode([0xffff], :int16, :big))
        assert_equal 1234, Codec.decode([1234], :scale, :big)
    end

    # 0x8000 is the int16/scale NOT_IMPLEMENTED bit pattern -- as a
    # *signed* value that is -32768, which the raw-bits check (not the
    # signed value) must still catch.
    def test_int16_not_implemented_sentinel_is_the_bit_pattern
        assert_nil Codec.decode([0x8000], :int16, :big)
        assert_nil Codec.decode([0x8000], :scale, :big)
    end

    def test_uint32_and_acc32_share_their_decode_width
        assert_equal 70_000, Codec.decode([1, 4464], :uint32, :big)
        assert_equal 70_000, Codec.decode([1, 4464], :acc32, :big)
        assert_nil Codec.decode([0xffff, 0xffff], :uint32, :big)
        # An acc32's "not implemented" is 0, so a counter really at 0
        # reads nil too.
        assert_nil Codec.decode([0, 0], :acc32, :big)
    end

    def test_int32_decodes_signed_and_flags_its_own_sentinel
        assert_equal(-1, Codec.decode([0xffff, 0xffff], :int32, :big))
        assert_nil Codec.decode([0x8000, 0], :int32, :big)
    end

    def test_uint64_decodes_and_flags_not_implemented
        assert_equal 1, Codec.decode([0, 0, 0, 1], :uint64, :big)
        sentinel = [0xffff] * 4
        assert_nil Codec.decode(sentinel, :uint64, :big)
    end

    # 25.0 is 0x41c80000 in IEEE 754, and exact.
    def test_float32_and_sefloat_decode_ieee754
        regs = [0x41c8, 0x0000]
        assert_in_delta 25.0, Codec.decode(regs, :float32, :big)
        assert_in_delta 25.0, Codec.decode(regs, :sefloat, :big)
    end

    # Both NOT_IMPLEMENTED bit patterns for these types (0x7fc00000 and
    # 0xffffffff) are themselves NaN float32 bit patterns -- "not
    # implemented" is decoded.nan?, not a table lookup (see codec.rb).
    def test_float_not_implemented_sentinels_are_both_nan
        assert_nil Codec.decode([0x7fc0, 0], :float32, :big)
        assert_nil Codec.decode([0xffff, 0xffff], :sefloat, :big)
    end

    def test_string_decodes_utf8_and_strips_nuls_and_trailing_space
        bytes = "#{"SunS".b}\x00\x00\x00\x00"
        regs = bytes.unpack("n*")
        assert_equal "SunS", Codec.decode(regs, :string, :big)
    end

    def test_an_unset_string_reads_as_nil
        regs = "\x00\x00\x00\x00".unpack("n*")
        assert_nil Codec.decode(regs, :string, :big)
    end

    # A value one off each sentinel is a value, not "not implemented".
    def test_values_beside_the_sentinels_are_values
        assert_equal 0xfffe, Codec.decode([0xfffe], :uint16, :big)
        assert_equal(-32_767, Codec.decode([0x8001], :int16, :big))
        assert_equal 0, Codec.decode([0], :uint16, :big)
    end

    # A string's bytes are in order whatever the device's wordorder.
    def test_strings_ignore_wordorder
        regs = "LG Cham\x00".b.unpack("n*")
        assert_equal "LG Cham", Codec.decode(regs, :string, :little)
        assert_equal regs, Codec.encode("LG Cham\x00", :string, :little)
    end

    # A uint16 over two registers (battery event_log) is its first.
    def test_a_16bit_value_reads_the_first_of_its_registers
        assert_equal 1, Codec.decode([1, 2], :uint16, :little)
        assert_equal 1, Codec.decode([1, 2], :uint16, :big)
    end

    def test_encode_pads_an_odd_string_with_a_nul
        assert_equal [0x6162, 0x6300], Codec.encode("abc", :string, :big)
    end

    # struct.pack refuses these where Array#pack would wrap them.
    def test_encode_refuses_what_does_not_fit_its_type
        [[65_536, :uint16], [-1, :uint16], [50.9, :uint16],
         [40_000, :int16], [2**32, :uint32], [-1, :uint64],
         [2**31, :int32], [1e39, :float32], ["1", :float32]]
            .each do |value, dtype|
                assert_raises(Error, "#{value} as #{dtype}") do
                    Codec.encode(value, dtype, :big)
                end
            end
    end

    def test_encode_takes_the_edges_of_each_range
        assert_equal [0xffff], Codec.encode(65_535, :uint16, :big)
        assert_equal [0x8000], Codec.encode(-32_768, :int16, :big)
        assert_equal [0x4120, 0], Codec.encode(10, :float32, :big)
    end

    # Low word first: 70000 is [1, 4464] big, [4464, 1] little.
    def test_wordorder_little_reverses_the_registers
        assert_equal 70_000, Codec.decode([4464, 1], :uint32, :little)
    end

    def test_encode_round_trips_through_decode
        %i[uint16 int16 uint32 int32 uint64].each do |dtype|
            registers = Codec.encode(42, dtype, :big)
            assert_equal 42, Codec.decode(registers, dtype, :big)
        end
    end

    def test_encode_float32_round_trips
        registers = Codec.encode(25.0, :float32, :big)
        assert_in_delta 25.0, Codec.decode(registers, :float32, :big)
    end

    # An accumulator is read-only.
    def test_encode_refuses_acc32
        assert_raises(Error) { Codec.encode(1, :acc32, :big) }
    end
end
