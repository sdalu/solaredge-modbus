# frozen_string_literal: true

module SolarEdge
    module Modbus
        # The remaining display/enumeration tables from __init__.py:
        # 132-175 of nmakel/solaredge_modbus @fd3ce7a (see modbus.rb
        # for the commit) -- the "fmt" column of the power-control and
        # StorEdge settings registers (Inverter batches 3-6, StorEdge).
        # Nothing here reads them; kept for a faithful port of the
        # enums.
        module ControlConstants
            EXPORT_CONTROL_MODE = { disabled: 0, direct_export: 1,
                                    indirect_export: 2,
                                    production_limitation: 3 }.freeze

            EXPORT_CONTROL_LIMIT = ["Total", "Per Phase"].freeze

            REACTIVE_POWER_CONFIG = [
                "Fixed CosPhi Mode", "Fixed Q Mode", "CosPhi(P) Mode",
                "Q(U) + Q(P) Mode", "RRCR Mode"
            ].freeze

            STOREDGE_CONTROL_MODE = { disabled: 0,
                                      maximize_self_consumption: 1,
                                      time_of_use: 2, backup_only: 3,
                                      remote_control: 4 }.freeze

            STOREDGE_AC_CHARGE_POLICY = { disabled: 0, always_allowed: 1,
                                          fixed_energy_limit: 2,
                                          percent_of_production: 3 }.freeze

            STOREDGE_CHARGE_DISCHARGE_MODE = {
                off: 0, charge_from_excess_pv_only: 1,
                charge_from_pv_first: 2, charge_from_pv_and_ac: 3,
                maximize_export: 4, discharge_to_match_load: 5,
                maximize_self_consumption: 7
            }.freeze
        end
    end
end
