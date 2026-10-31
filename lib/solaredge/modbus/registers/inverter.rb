# frozen_string_literal: true

module SolarEdge
    module Modbus
        module Registers
            # The inverter's registers: SunSpec Common (0x9c40) and
            # inverter model, then SolarEdge's power-control (0xf000) and
            # StorEdge settings (0xe004). From nmakel/solaredge_modbus
            # @fd3ce7a, __init__.py:487-567.
            module Inverter
                REGISTERS = {
                    c_id: [0x9c40, 2, :string, 1],
                    c_did: [0x9c42, 1, :uint16, 1],
                    c_length: [0x9c43, 1, :uint16, 1],
                    c_manufacturer: [0x9c44, 16, :string, 1],
                    c_model: [0x9c54, 16, :string, 1],
                    c_version: [0x9c6c, 8, :string, 1],
                    c_serialnumber: [0x9c74, 16, :string, 1],
                    c_deviceaddress: [0x9c84, 1, :uint16, 1],
                    c_sunspec_did: [0x9c85, 1, :uint16, 2],
                    c_sunspec_length: [0x9c86, 1, :uint16, 2],
                    current: [0x9c87, 1, :uint16, 2],
                    l1_current: [0x9c88, 1, :uint16, 2],
                    l2_current: [0x9c89, 1, :uint16, 2],
                    l3_current: [0x9c8a, 1, :uint16, 2],
                    current_scale: [0x9c8b, 1, :scale, 2],
                    l1_voltage: [0x9c8c, 1, :uint16, 2],
                    l2_voltage: [0x9c8d, 1, :uint16, 2],
                    l3_voltage: [0x9c8e, 1, :uint16, 2],
                    l1n_voltage: [0x9c8f, 1, :uint16, 2],
                    l2n_voltage: [0x9c90, 1, :uint16, 2],
                    l3n_voltage: [0x9c91, 1, :uint16, 2],
                    voltage_scale: [0x9c92, 1, :scale, 2],
                    power_ac: [0x9c93, 1, :int16, 2],
                    power_ac_scale: [0x9c94, 1, :scale, 2],
                    frequency: [0x9c95, 1, :uint16, 2],
                    frequency_scale: [0x9c96, 1, :scale, 2],
                    power_apparent: [0x9c97, 1, :int16, 2],
                    power_apparent_scale: [0x9c98, 1, :scale, 2],
                    power_reactive: [0x9c99, 1, :int16, 2],
                    power_reactive_scale: [0x9c9a, 1, :scale, 2],
                    power_factor: [0x9c9b, 1, :int16, 2],
                    power_factor_scale: [0x9c9c, 1, :scale, 2],
                    energy_total: [0x9c9d, 2, :acc32, 2],
                    energy_total_scale: [0x9c9f, 1, :scale, 2],
                    current_dc: [0x9ca0, 1, :uint16, 2],
                    current_dc_scale: [0x9ca1, 1, :scale, 2],
                    voltage_dc: [0x9ca2, 1, :uint16, 2],
                    voltage_dc_scale: [0x9ca3, 1, :scale, 2],
                    power_dc: [0x9ca4, 1, :int16, 2],
                    power_dc_scale: [0x9ca5, 1, :scale, 2],
                    temperature: [0x9ca7, 1, :int16, 2],
                    temperature_scale: [0x9caa, 1, :scale, 2],
                    status: [0x9cab, 1, :uint16, 2],
                    vendor_status: [0x9cac, 1, :uint16, 2],
                    rrcr_state: [0xf000, 1, :uint16, 3],
                    active_power_limit: [0xf001, 1, :uint16, 3],
                    cosphi: [0xf002, 2, :float32, 3],
                    commit_power_control_settings: [0xf100, 1, :int16, 4],
                    restore_power_control_default_settings:
                        [0xf101, 1, :int16, 4],
                    reactive_power_config: [0xf103, 2, :int32, 4],
                    reactive_power_response_time: [0xf105, 2, :uint32, 4],
                    advanced_power_control_enable: [0xf142, 2, :uint16, 4],
                    export_control_mode: [0xf700, 1, :uint16, 5],
                    export_control_limit_mode: [0xf701, 1, :uint16, 5],
                    export_control_site_limit: [0xf702, 2, :float32, 5],
                    storage_control_mode: [0xe004, 1, :uint16, 6],
                    storage_ac_charge_policy: [0xe005, 1, :uint16, 6],
                    storage_ac_charge_limit: [0xe006, 2, :float32, 6],
                    storage_backup_reserved_setting: [0xe008, 2, :float32, 6],
                    storage_default_mode: [0xe00a, 1, :uint16, 6],
                    rc_cmd_timeout: [0xe00b, 2, :uint32, 6],
                    rc_cmd_mode: [0xe00d, 1, :uint16, 6],
                    rc_charge_limit: [0xe00e, 2, :float32, 6],
                    rc_discharge_limit: [0xe010, 2, :float32, 6]
                }.transform_values { Register.new(*it) }.freeze

                # The power-control and StorEdge settings registers put
                # their low word first; the others do not.
                LITTLE_ENDIAN = [0xf700, 0xf701, 0xf702, 0xe004, 0xe005,
                                 0xe006, 0xe008, 0xe00a, 0xe00b, 0xe00d,
                                 0xe00e, 0xe010].freeze
            end
        end
    end
end
