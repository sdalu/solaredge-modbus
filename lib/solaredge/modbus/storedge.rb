# frozen_string_literal: true

module SolarEdge
    module Modbus
        # An inverter's StorEdge (battery-system) settings,
        # __init__.py:694-717 of nmakel/solaredge_modbus @fd3ce7a (see
        # modbus.rb for the commit): Registers::StorEdge's table, no
        # per-instance offset, wordorder LITTLE throughout
        # (self.wordorder = Endian.LITTLE, __init__.py:698).
        class StorEdge < Device
            REGISTERS = Registers::StorEdge::REGISTERS
            WORDORDER = :little
        end
    end
end
