# frozen_string_literal: true

require "solaredge/modbus/register"

module SolarEdge
    module Modbus
        module Registers
            # The StorEdge settings registers (SolarEdge's own, at
            # 0xe000). From nmakel/solaredge_modbus @fd3ce7a,
            # __init__.py:702-717.
            module StorEdge
                REGISTERS = {
                    export_control_mode: [0xe000, 1, :uint16, 1],
                    export_control_limit_mode: [0xe001, 1, :uint16, 1],
                    export_control_site_limit: [0xe002, 2, :sefloat, 1],
                    storedge_control_mode: [0xe004, 1, :uint16, 1],
                    storedge_ac_charge_policy: [0xe005, 1, :uint16, 1],
                    storedge_ac_charge_limit: [0xe006, 2, :sefloat, 1],
                    storedge_backup_reserved: [0xe008, 2, :sefloat, 1],
                    storedge_remote_default_command_mode:
                        [0xe00a, 1, :uint16, 1],
                    storedge_remote_command_timeout: [0xe00b, 2, :uint32, 1],
                    storedge_remote_command_mode: [0xe00d, 1, :uint16, 1],
                    storedge_remote_charge_limit: [0xe00e, 2, :sefloat, 1],
                    storedge_remote_discharge_limit: [0xe010, 2, :sefloat, 1]
                }.transform_values { Register.row(*it) }.freeze
            end
        end
    end
end
