# frozen_string_literal: true

module SolarEdge
    module Modbus
        module Registers
            # Meter's SunSpec Common + Meter model registers, base
            # addresses (offset 0, meter 1) ported register for register
            # from __init__.py:602-692 of nmakel/solaredge_modbus
            # @fd3ce7a (Meter#__init__'s self.registers; see
            # modbus.rb for the commit). SolarEdge::Meter adds its
            # instance offset (Constants::METER_REGISTER_OFFSETS) to
            # every address at read time.
            # rubocop:disable Metrics/ModuleLength -- a flat data table,
            # one line per upstream register; splitting it in two would
            # only make the two halves harder to eyeball against
            # __init__.py.
            module Meter
                r = lambda do |address, length, dtype, vtype, batch|
                    Register.new(address:, length:, rtype: :holding,
                                 dtype:, vtype:, batch:)
                end

                REGISTERS = {
                    c_manufacturer: r.call(0x9cbb, 16, :string, :str, 1),
                    c_model: r.call(0x9ccb, 16, :string, :str, 1),
                    c_option: r.call(0x9cdb, 8, :string, :str, 1),
                    c_version: r.call(0x9ce3, 8, :string, :str, 1),
                    c_serialnumber: r.call(0x9ceb, 16, :string, :str, 1),
                    c_deviceaddress: r.call(0x9cfb, 1, :uint16, :int, 1),
                    c_sunspec_did: r.call(0x9cfc, 1, :uint16, :int, 2),
                    c_sunspec_length: r.call(0x9cfd, 1, :uint16, :int, 2),
                    current: r.call(0x9cfe, 1, :int16, :int, 2),
                    l1_current: r.call(0x9cff, 1, :int16, :int, 2),
                    l2_current: r.call(0x9d00, 1, :int16, :int, 2),
                    l3_current: r.call(0x9d01, 1, :int16, :int, 2),
                    current_scale: r.call(0x9d02, 1, :scale, :int, 2),
                    voltage_ln: r.call(0x9d03, 1, :int16, :int, 2),
                    l1n_voltage: r.call(0x9d04, 1, :int16, :int, 2),
                    l2n_voltage: r.call(0x9d05, 1, :int16, :int, 2),
                    l3n_voltage: r.call(0x9d06, 1, :int16, :int, 2),
                    voltage_ll: r.call(0x9d07, 1, :int16, :int, 2),
                    l12_voltage: r.call(0x9d08, 1, :int16, :int, 2),
                    l23_voltage: r.call(0x9d09, 1, :int16, :int, 2),
                    l31_voltage: r.call(0x9d0a, 1, :int16, :int, 2),
                    voltage_scale: r.call(0x9d0b, 1, :scale, :int, 2),
                    frequency: r.call(0x9d0c, 1, :int16, :int, 2),
                    frequency_scale: r.call(0x9d0d, 1, :scale, :int, 2),
                    power: r.call(0x9d0e, 1, :int16, :int, 2),
                    l1_power: r.call(0x9d0f, 1, :int16, :int, 2),
                    l2_power: r.call(0x9d10, 1, :int16, :int, 2),
                    l3_power: r.call(0x9d11, 1, :int16, :int, 2),
                    power_scale: r.call(0x9d12, 1, :scale, :int, 2),
                    power_apparent: r.call(0x9d13, 1, :int16, :int, 2),
                    l1_power_apparent: r.call(0x9d14, 1, :int16, :int, 2),
                    l2_power_apparent: r.call(0x9d15, 1, :int16, :int, 2),
                    l3_power_apparent: r.call(0x9d16, 1, :int16, :int, 2),
                    power_apparent_scale: r.call(0x9d17, 1, :scale, :int, 2),
                    power_reactive: r.call(0x9d18, 1, :int16, :int, 2),
                    l1_power_reactive: r.call(0x9d19, 1, :int16, :int, 2),
                    l2_power_reactive: r.call(0x9d1a, 1, :int16, :int, 2),
                    l3_power_reactive: r.call(0x9d1b, 1, :int16, :int, 2),
                    power_reactive_scale: r.call(0x9d1c, 1, :scale, :int, 2),
                    power_factor: r.call(0x9d1d, 1, :int16, :int, 2),
                    l1_power_factor: r.call(0x9d1e, 1, :int16, :int, 2),
                    l2_power_factor: r.call(0x9d1f, 1, :int16, :int, 2),
                    l3_power_factor: r.call(0x9d20, 1, :int16, :int, 2),
                    power_factor_scale: r.call(0x9d21, 1, :scale, :int, 2),
                    export_energy_active: r.call(0x9d22, 2, :uint32, :int, 2),
                    l1_export_energy_active:
                        r.call(0x9d24, 2, :uint32, :int, 2),
                    l2_export_energy_active:
                        r.call(0x9d26, 2, :uint32, :int, 2),
                    l3_export_energy_active:
                        r.call(0x9d28, 2, :uint32, :int, 2),
                    import_energy_active: r.call(0x9d2a, 2, :uint32, :int, 2),
                    l1_import_energy_active:
                        r.call(0x9d2c, 2, :uint32, :int, 2),
                    l2_import_energy_active:
                        r.call(0x9d2e, 2, :uint32, :int, 2),
                    l3_import_energy_active:
                        r.call(0x9d30, 2, :uint32, :int, 2),
                    energy_active_scale: r.call(0x9d32, 1, :scale, :int, 2),
                    export_energy_apparent:
                        r.call(0x9d33, 2, :uint32, :int, 3),
                    l1_export_energy_apparent:
                        r.call(0x9d35, 2, :uint32, :int, 3),
                    l2_export_energy_apparent:
                        r.call(0x9d37, 2, :uint32, :int, 3),
                    l3_export_energy_apparent:
                        r.call(0x9d39, 2, :uint32, :int, 3),
                    import_energy_apparent:
                        r.call(0x9d3b, 2, :uint32, :int, 3),
                    l1_import_energy_apparent:
                        r.call(0x9d3d, 2, :uint32, :int, 3),
                    l2_import_energy_apparent:
                        r.call(0x9d3f, 2, :uint32, :int, 3),
                    l3_import_energy_apparent:
                        r.call(0x9d41, 2, :uint32, :int, 3),
                    energy_apparent_scale: r.call(0x9d43, 1, :scale, :int, 3),
                    import_energy_reactive_q1:
                        r.call(0x9d44, 2, :uint32, :int, 3),
                    l1_import_energy_reactive_q1:
                        r.call(0x9d46, 2, :uint32, :int, 3),
                    l2_import_energy_reactive_q1:
                        r.call(0x9d48, 2, :uint32, :int, 3),
                    l3_import_energy_reactive_q1:
                        r.call(0x9d4a, 2, :uint32, :int, 3),
                    import_energy_reactive_q2:
                        r.call(0x9d4c, 2, :uint32, :int, 3),
                    l1_import_energy_reactive_q2:
                        r.call(0x9d4e, 2, :uint32, :int, 3),
                    l2_import_energy_reactive_q2:
                        r.call(0x9d50, 2, :uint32, :int, 3),
                    l3_import_energy_reactive_q2:
                        r.call(0x9d52, 2, :uint32, :int, 3),
                    export_energy_reactive_q3:
                        r.call(0x9d54, 2, :uint32, :int, 3),
                    l1_export_energy_reactive_q3:
                        r.call(0x9d56, 2, :uint32, :int, 3),
                    l2_export_energy_reactive_q3:
                        r.call(0x9d58, 2, :uint32, :int, 3),
                    l3_export_energy_reactive_q3:
                        r.call(0x9d5a, 2, :uint32, :int, 3),
                    export_energy_reactive_q4:
                        r.call(0x9d5c, 2, :uint32, :int, 3),
                    l1_export_energy_reactive_q4:
                        r.call(0x9d5e, 2, :uint32, :int, 3),
                    l2_export_energy_reactive_q4:
                        r.call(0x9d60, 2, :uint32, :int, 3),
                    l3_export_energy_reactive_q4:
                        r.call(0x9d62, 2, :uint32, :int, 3),
                    energy_reactive_scale: r.call(0x9d64, 1, :scale, :int, 3)
                }.freeze
            end
            # rubocop:enable Metrics/ModuleLength
        end
    end
end
