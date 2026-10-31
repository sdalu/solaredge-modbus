# frozen_string_literal: true

require "solaredge/modbus/register"

module SolarEdge
    module Modbus
        module Registers
            # Battery 1's registers (SolarEdge's own, at 0xe100); the
            # other is at Battery::OFFSETS from these. From
            # nmakel/solaredge_modbus @fd3ce7a, __init__.py:728-763.
            module Battery
                REGISTERS = {
                    c_manufacturer: [0xe100, 16, :string, 1],
                    c_model: [0xe110, 16, :string, 1],
                    c_version: [0xe120, 16, :string, 1],
                    c_serialnumber: [0xe130, 16, :string, 1],
                    c_deviceaddress: [0xe140, 1, :uint16, 1],
                    c_sunspec_did: [0xe141, 1, :uint16, 1],
                    rated_energy: [0xe142, 2, :sefloat, 2],
                    maximum_charge_continuous_power: [0xe144, 2, :sefloat, 2],
                    maximum_discharge_continuous_power:
                        [0xe146, 2, :sefloat, 2],
                    maximum_charge_peak_power: [0xe148, 2, :sefloat, 2],
                    maximum_discharge_peak_power: [0xe14a, 2, :sefloat, 2],
                    average_temperature: [0xe16c, 2, :sefloat, 2],
                    maximum_temperature: [0xe16e, 2, :sefloat, 2],
                    instantaneous_voltage: [0xe170, 2, :sefloat, 2],
                    instantaneous_current: [0xe172, 2, :sefloat, 2],
                    instantaneous_power: [0xe174, 2, :sefloat, 2],
                    lifetime_export_energy_counter: [0xe176, 4, :uint64, 2],
                    lifetime_import_energy_counter: [0xe17a, 4, :uint64, 2],
                    maximum_energy: [0xe17e, 2, :sefloat, 2],
                    available_energy: [0xe180, 2, :sefloat, 2],
                    soh: [0xe182, 2, :sefloat, 2],
                    soe: [0xe184, 2, :sefloat, 2],
                    status: [0xe186, 2, :uint32, 2],
                    status_internal: [0xe188, 2, :uint32, 2],
                    event_log: [0xe18a, 2, :uint16, 2],
                    event_log_internal: [0xe192, 2, :uint16, 2]
                }.transform_values { Register.row(*it) }.freeze
            end
        end
    end
end
