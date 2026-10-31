# frozen_string_literal: true

module SolarEdge
    module Modbus
        # What the coded registers' values mean, each table name => code:
        # look one up with `.key(code)`, as in
        # `Constants::INVERTER_STATUS.key(inverter.read(:status))`.
        module Constants
            # The Common block's c_sunspec_did: which SunSpec model a
            # device implements.
            SUNSPEC_DID = {
                single_phase_inverter: 101, split_phase_inverter: 102,
                three_phase_inverter: 103, single_phase_meter: 201,
                split_phase_meter: 202, wye_three_phase_meter: 203,
                delta_three_phase_meter: 204, battery_base: 802,
                li_battery_bank: 803, li_battery_string: 804,
                li_battery_module: 805, flow_battery: 806,
                flow_battery_string: 807, flow_battery_module: 808,
                flow_battery_stack: 809
            }.freeze

            # Inverter status.
            INVERTER_STATUS = {
                undefined: 0, off: 1, sleeping: 2, grid_monitoring: 3,
                producing: 4, throttled: 5, shutting_down: 6, fault: 7,
                standby: 8
            }.freeze

            # Battery status and status_internal.
            BATTERY_STATUS = { off: 0, standby: 1, init: 2, charge: 3,
                               discharge: 4, fault: 5, idle: 6 }.freeze

            # Inverter export_control_mode.
            EXPORT_CONTROL_MODE = { disabled: 0, direct_export: 1,
                                    indirect_export: 2,
                                    production_limitation: 3 }.freeze

            # Inverter export_control_limit_mode.
            EXPORT_CONTROL_LIMIT = { total: 0, per_phase: 1 }.freeze

            # Inverter reactive_power_config.
            REACTIVE_POWER_CONFIG = { fixed_cosphi: 0, fixed_q: 1,
                                      cosphi_p: 2, q_u_q_p: 3,
                                      rrcr: 4 }.freeze

            # storage_control_mode / storedge_control_mode.
            STOREDGE_CONTROL_MODE = { disabled: 0,
                                      maximize_self_consumption: 1,
                                      time_of_use: 2, backup_only: 3,
                                      remote_control: 4 }.freeze

            # storage_ac_charge_policy / storedge_ac_charge_policy.
            STOREDGE_AC_CHARGE_POLICY = { disabled: 0, always_allowed: 1,
                                          fixed_energy_limit: 2,
                                          percent_of_production: 3 }.freeze

            # The default and remote command modes (storage_default_mode,
            # rc_cmd_mode, storedge_remote_*_command_mode).
            STOREDGE_CHARGE_DISCHARGE_MODE = {
                off: 0, charge_from_excess_pv_only: 1,
                charge_from_pv_first: 2, charge_from_pv_and_ac: 3,
                maximize_export: 4, discharge_to_match_load: 5,
                maximize_self_consumption: 7
            }.freeze
        end
    end
end
