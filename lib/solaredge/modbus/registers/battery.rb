# frozen_string_literal: true

module SolarEdge
    module Modbus
        module Registers
            # Battery's registers, base addresses (offset 0, battery 1)
            # ported register for register from __init__.py:728-763 of
            # nmakel/solaredge_modbus @fd3ce7a (Battery#__init__'s
            # self.registers; see modbus.rb for the commit).
            # SolarEdge::Battery adds its instance offset
            # (Constants::BATTERY_REGISTER_OFFSETS) to every address at
            # read time. Wordorder is LITTLE for the whole class
            # (SolarEdge::Battery::WORDORDER); Codec applies it to 32-
            # and 64-bit values only.
            module Battery
                r = lambda do |address, length, dtype, vtype, batch|
                    Register.new(address:, length:, rtype: :holding,
                                 dtype:, vtype:, batch:)
                end

                REGISTERS = {
                    c_manufacturer: r.call(0xe100, 16, :string, :str, 1),
                    c_model: r.call(0xe110, 16, :string, :str, 1),
                    c_version: r.call(0xe120, 16, :string, :str, 1),
                    c_serialnumber: r.call(0xe130, 16, :string, :str, 1),
                    c_deviceaddress: r.call(0xe140, 1, :uint16, :int, 1),
                    c_sunspec_did: r.call(0xe141, 1, :uint16, :int, 1),
                    rated_energy: r.call(0xe142, 2, :sefloat, :float, 2),
                    maximum_charge_continuous_power:
                        r.call(0xe144, 2, :sefloat, :float, 2),
                    maximum_discharge_continuous_power:
                        r.call(0xe146, 2, :sefloat, :float, 2),
                    maximum_charge_peak_power:
                        r.call(0xe148, 2, :sefloat, :float, 2),
                    maximum_discharge_peak_power:
                        r.call(0xe14a, 2, :sefloat, :float, 2),
                    average_temperature: r.call(0xe16c, 2, :sefloat, :float, 2),
                    maximum_temperature: r.call(0xe16e, 2, :sefloat, :float, 2),
                    instantaneous_voltage:
                        r.call(0xe170, 2, :sefloat, :float, 2),
                    instantaneous_current:
                        r.call(0xe172, 2, :sefloat, :float, 2),
                    instantaneous_power: r.call(0xe174, 2, :sefloat, :float, 2),
                    lifetime_export_energy_counter:
                        r.call(0xe176, 4, :uint64, :int, 2),
                    lifetime_import_energy_counter:
                        r.call(0xe17a, 4, :uint64, :int, 2),
                    maximum_energy: r.call(0xe17e, 2, :sefloat, :float, 2),
                    available_energy: r.call(0xe180, 2, :sefloat, :float, 2),
                    soh: r.call(0xe182, 2, :sefloat, :float, 2),
                    soe: r.call(0xe184, 2, :sefloat, :float, 2),
                    status: r.call(0xe186, 2, :uint32, :int, 2),
                    status_internal: r.call(0xe188, 2, :uint32, :int, 2),
                    event_log: r.call(0xe18a, 2, :uint16, :int, 2),
                    event_log_internal: r.call(0xe192, 2, :uint16, :int, 2)
                }.freeze
            end
        end
    end
end
