# frozen_string_literal: true

module SolarEdge
    module Modbus
        # Enumerations and lookup tables ported from __init__.py:17-186
        # of nmakel/solaredge_modbus @fd3ce7a (see modbus.rb for the
        # commit). Kept even where nothing here calls them yet (the
        # SunSpec DID map, the control-register maps): the port carries
        # every enum upstream has, not only the ones in use.
        module Constants
            # sunspecDID, __init__.py:17-32 (model IDs of the Common
            # Model's c_sunspec_did field).
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

            # inverterStatus, __init__.py:35-43 (1-based; unused by the
            # decode path -- INVERTER_STATUS below is what "status"
            # actually maps through).
            INVERTER_STATUS = { off: 1, sleeping: 2, starting: 3, mppt: 4,
                                throttled: 5, shutting_down: 6, fault: 7,
                                standby: 8 }.freeze

            # INVERTER_STATUS_MAP, __init__.py:110-120: the inverter's
            # "status" register (0-8) as a label, indexed directly (not
            # status-1), in upstream's spelling.
            INVERTER_STATUS_MAP = [
                "Undefined", "Off", "Sleeping", "Grid Monitoring",
                "Producing", "Producing (Throttled)", "Shutting Down",
                "Fault", "Standby"
            ].freeze

            # batteryStatus, __init__.py:46-53 (1-based; likewise unused
            # by decode -- BATTERY_STATUS_MAP, 0-based, is what the
            # battery "status"/"status_internal" registers map through).
            BATTERY_STATUS = { off: 1, empty: 2, discharging: 3,
                               charging: 4, full: 5, holding: 6,
                               testing: 7 }.freeze

            BATTERY_STATUS_MAP = %w[Off Standby Init Charge Discharge
                                    Fault Idle].freeze

            # __init__.py:177-186: per-instance address offset, meter 1
            # /battery 1 first. Meter index 2's probe id (see
            # Registers::INVERTER::METER_DIDS) is one past 0x9cfc +
            # this table's 0x15c -- kept as upstream wrote it.
            METER_REGISTER_OFFSETS   = [0x0, 0xae, 0x15c].freeze
            BATTERY_REGISTER_OFFSETS = [0x0, 0x100].freeze
        end
    end
end
