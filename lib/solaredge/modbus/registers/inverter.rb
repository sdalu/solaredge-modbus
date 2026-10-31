# frozen_string_literal: true

module SolarEdge
    module Modbus
        module Registers
            # Inverter's SunSpec Common + Inverter model registers,
            # ported register for register from __init__.py:487-567 of
            # nmakel/solaredge_modbus @fd3ce7a (Inverter#__init__'s
            # self.registers; see modbus.rb for the commit). Every
            # register is rtype :holding, as upstream has it.
            module Inverter
                r = lambda do |address, length, dtype, vtype, batch|
                    Register.new(address:, length:, rtype: :holding,
                                 dtype:, vtype:, batch:)
                end

                REGISTERS = {
                    c_id: r.call(0x9c40, 2, :string, :str, 1),
                    c_did: r.call(0x9c42, 1, :uint16, :int, 1),
                    c_length: r.call(0x9c43, 1, :uint16, :int, 1),
                    c_manufacturer: r.call(0x9c44, 16, :string, :str, 1),
                    c_model: r.call(0x9c54, 16, :string, :str, 1),
                    c_version: r.call(0x9c6c, 8, :string, :str, 1),
                    c_serialnumber: r.call(0x9c74, 16, :string, :str, 1),
                    c_deviceaddress: r.call(0x9c84, 1, :uint16, :int, 1),
                    c_sunspec_did: r.call(0x9c85, 1, :uint16, :int, 2),
                    c_sunspec_length: r.call(0x9c86, 1, :uint16, :int, 2),
                    current: r.call(0x9c87, 1, :uint16, :int, 2),
                    l1_current: r.call(0x9c88, 1, :uint16, :int, 2),
                    l2_current: r.call(0x9c89, 1, :uint16, :int, 2),
                    l3_current: r.call(0x9c8a, 1, :uint16, :int, 2),
                    current_scale: r.call(0x9c8b, 1, :scale, :int, 2),
                    l1_voltage: r.call(0x9c8c, 1, :uint16, :int, 2),
                    l2_voltage: r.call(0x9c8d, 1, :uint16, :int, 2),
                    l3_voltage: r.call(0x9c8e, 1, :uint16, :int, 2),
                    l1n_voltage: r.call(0x9c8f, 1, :uint16, :int, 2),
                    l2n_voltage: r.call(0x9c90, 1, :uint16, :int, 2),
                    l3n_voltage: r.call(0x9c91, 1, :uint16, :int, 2),
                    voltage_scale: r.call(0x9c92, 1, :scale, :int, 2),
                    power_ac: r.call(0x9c93, 1, :int16, :int, 2),
                    power_ac_scale: r.call(0x9c94, 1, :scale, :int, 2),
                    frequency: r.call(0x9c95, 1, :uint16, :int, 2),
                    frequency_scale: r.call(0x9c96, 1, :scale, :int, 2),
                    power_apparent: r.call(0x9c97, 1, :int16, :int, 2),
                    power_apparent_scale: r.call(0x9c98, 1, :scale, :int, 2),
                    power_reactive: r.call(0x9c99, 1, :int16, :int, 2),
                    power_reactive_scale: r.call(0x9c9a, 1, :scale, :int, 2),
                    power_factor: r.call(0x9c9b, 1, :int16, :int, 2),
                    power_factor_scale: r.call(0x9c9c, 1, :scale, :int, 2),
                    energy_total: r.call(0x9c9d, 2, :acc32, :int, 2),
                    energy_total_scale: r.call(0x9c9f, 1, :scale, :int, 2),
                    current_dc: r.call(0x9ca0, 1, :uint16, :int, 2),
                    current_dc_scale: r.call(0x9ca1, 1, :scale, :int, 2),
                    voltage_dc: r.call(0x9ca2, 1, :uint16, :int, 2),
                    voltage_dc_scale: r.call(0x9ca3, 1, :scale, :int, 2),
                    power_dc: r.call(0x9ca4, 1, :int16, :int, 2),
                    power_dc_scale: r.call(0x9ca5, 1, :scale, :int, 2),
                    temperature: r.call(0x9ca7, 1, :int16, :int, 2),
                    temperature_scale: r.call(0x9caa, 1, :scale, :int, 2),
                    status: r.call(0x9cab, 1, :uint16, :int, 2),
                    vendor_status: r.call(0x9cac, 1, :uint16, :int, 2),
                    rrcr_state: r.call(0xf000, 1, :uint16, :int, 3),
                    active_power_limit: r.call(0xf001, 1, :uint16, :int, 3),
                    cosphi: r.call(0xf002, 2, :float32, :int, 3),
                    commit_power_control_settings:
                        r.call(0xf100, 1, :int16, :int, 4),
                    restore_power_control_default_settings:
                        r.call(0xf101, 1, :int16, :int, 4),
                    reactive_power_config: r.call(0xf103, 2, :int32, :int, 4),
                    reactive_power_response_time:
                        r.call(0xf105, 2, :uint32, :int, 4),
                    advanced_power_control_enable:
                        r.call(0xf142, 2, :uint16, :int, 4),
                    export_control_mode: r.call(0xf700, 1, :uint16, :int, 5),
                    export_control_limit_mode:
                        r.call(0xf701, 1, :uint16, :int, 5),
                    export_control_site_limit:
                        r.call(0xf702, 2, :float32, :int, 5),
                    storage_control_mode: r.call(0xe004, 1, :uint16, :int, 6),
                    storage_ac_charge_policy:
                        r.call(0xe005, 1, :uint16, :int, 6),
                    storage_ac_charge_limit:
                        r.call(0xe006, 2, :float32, :float, 6),
                    storage_backup_reserved_setting:
                        r.call(0xe008, 2, :float32, :float, 6),
                    storage_default_mode:
                        r.call(0xe00a, 1, :uint16, :int, 6),
                    rc_cmd_timeout: r.call(0xe00b, 2, :uint32, :int, 6),
                    rc_cmd_mode: r.call(0xe00d, 1, :uint16, :int, 6),
                    rc_charge_limit: r.call(0xe00e, 2, :float32, :float, 6),
                    rc_discharge_limit: r.call(0xe010, 2, :float32, :float, 6)
                }.freeze

                # little_endian_registers, __init__.py:470-483: the
                # power-control and StorEdge settings registers want
                # wordorder LITTLE where every other Inverter register
                # wants BIG (Device::WORDORDER).
                LITTLE_ENDIAN = [0xf700, 0xf701, 0xf702, 0xe004, 0xe005,
                                 0xe006, 0xe008, 0xe00a, 0xe00b, 0xe00d,
                                 0xe00e, 0xe010].freeze

                # meter_dids / battery_dids, __init__.py:571-581: probe
                # addresses for #meters and #batteries, each meter's
                # c_sunspec_did: 0x9cfc + METER_REGISTER_OFFSETS[i].
                # (Upstream's third, 0x9e59, is one past it.)
                METER_DIDS = [0x9cfc, 0x9daa, 0x9e58].freeze
                BATTERY_DIDS = [0xe140, 0xe240].freeze
            end
        end
    end
end
