# frozen_string_literal: true

module SolarEdge
    module Modbus
        module Registers
            # StorEdge's registers, ported register for register from
            # __init__.py:702-717 of nmakel/solaredge_modbus @fd3ce7a
            # (StorEdge#__init__'s self.registers; see modbus.rb for
            # the commit). Wordorder is LITTLE for all of them
            # (SolarEdge::StorEdge::WORDORDER).
            module StorEdge
                r = lambda do |address, length, dtype, vtype, batch|
                    Register.new(address:, length:, rtype: :holding,
                                 dtype:, vtype:, batch:)
                end

                REGISTERS = {
                    export_control_mode: r.call(0xe000, 1, :uint16, :int, 1),
                    export_control_limit_mode:
                        r.call(0xe001, 1, :uint16, :int, 1),
                    export_control_site_limit:
                        r.call(0xe002, 2, :sefloat, :float, 1),
                    storedge_control_mode:
                        r.call(0xe004, 1, :uint16, :int, 1),
                    storedge_ac_charge_policy:
                        r.call(0xe005, 1, :uint16, :int, 1),
                    storedge_ac_charge_limit:
                        r.call(0xe006, 2, :sefloat, :float, 1),
                    storedge_backup_reserved:
                        r.call(0xe008, 2, :sefloat, :float, 1),
                    storedge_remote_default_command_mode:
                        r.call(0xe00a, 1, :uint16, :int, 1),
                    storedge_remote_command_timeout:
                        r.call(0xe00b, 2, :uint32, :int, 1),
                    storedge_remote_command_mode:
                        r.call(0xe00d, 1, :uint16, :int, 1),
                    storedge_remote_charge_limit:
                        r.call(0xe00e, 2, :sefloat, :float, 1),
                    storedge_remote_discharge_limit:
                        r.call(0xe010, 2, :sefloat, :float, 1)
                }.freeze
            end
        end
    end
end
