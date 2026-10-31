# solaredge-modbus

Read and write a SolarEdge inverter over Modbus TCP: the inverter
itself, the meters and batteries attached to it, and its StorEdge
settings, through the SunSpec registers SolarEdge exposes. A Ruby port
of [nmakel/solaredge_modbus](https://github.com/nmakel/solaredge_modbus)
at commit `fd3ce7a` (2025-01-08): same register tables, same names, same
decoding, without its bugs (DESIGN.md lists where it departs).

It needs only Ruby's standard library (Ruby 3.4).

## Use

```ruby
require "solaredge/modbus"

inverter = SolarEdge::Modbus::Inverter.new(host: "192.168.1.30",
                                           port: 1502)
begin
    status = SolarEdge::Modbus::Constants::INVERTER_STATUS
             .key(inverter.read(:status))
    power = inverter.read(:power_ac) * 10.0**inverter.read(:power_ac_scale)
    puts "#{status}, #{power} W"

    inverter.read_all.each { |name, value| puts "#{name}: #{value}" }

    inverter.meters.each do |meter|
        net = meter.read(:power) * 10.0**meter.read(:power_scale)
        puts "meter #{meter.number}: #{net} W at the grid connection"
    end
    inverter.batteries.each do |battery|
        puts "battery #{battery.number}: #{battery.read(:soe)} %"
    end
ensure
    inverter.disconnect
end
```

- `Device#read(name)` reads one register and decodes it to an Integer,
  a Float or a String by its type; `read_all` reads every register,
  one request per batch of neighbours, and returns `{ name => value }`.
  The names are in `lib/solaredge/modbus/registers/`.
- Values are raw: a quantity and its `_scale` register are read
  separately, and the value is `quantity * 10**scale`. A coded value
  (a status, a mode) is named by `Constants`: `INVERTER_STATUS.key(4)`
  is `:producing`.
- A register holding SunSpec's "not implemented" value (0xffff for a
  uint16, 0x8000 for an int16 or scale factor, NaN for a float, 0 for
  an `acc32` counter, an empty string) decodes to `nil`, so check a
  value and its scale before multiplying.
- `read` tries three times, reconnecting as needed, then raises
  `SolarEdge::Modbus::Error`: refused connection, a reply that does
  not answer the request (transaction, unit, function, lengths), or
  one not whole within the timeout (3 s from the request). Each closes
  the connection. A device's exception reply raises
  `SolarEdge::Modbus::ModbusException` (an `Error`, with `code` and
  `function`) at once, as another try would get the same answer.
- `read_all` leaves out a batch the device answers with an exception
  reply (registers it does not have) and raises on any other failure.
- An unknown register name raises `Error`.
- `Device#write(name, value)` encodes and writes one register and
  returns `nil`; it raises `Error` for a value its type cannot hold (an
  Integer in range for integer registers, a number within float32 for
  float ones).
  Nothing here has been written to a real inverter: writes are checked
  only against the framing tests.
- A device connects on its first read and stays connected until
  `disconnect`. `Inverter#meters` and `#batteries` return the devices
  present, each with its `number` (from 1), sharing the inverter's
  connection.
- `Meter.new(number: 1..3, host:, port:)`, `Battery.new(number: 1..2,
  …)` and `StorEdge.new(…)` build a device directly (a number out of
  range raises `ArgumentError`); `parent:` shares another device's
  connection, and `transport:` takes any object answering
  `connected?`, `connect`, `close`, `read_registers` and
  `write_registers`, which is how the tests run without a socket.

## Known shortfalls

- SolarEdge's register map only. Addresses are SolarEdge's fixed ones
  (Common at 40000, meters at fixed offsets), with no SunSpec model
  discovery and no float models (111–113, 211–214): this does not read
  a Fronius or SMA inverter.
- SolarEdge inverters are reported to accept one Modbus TCP client at a
  time. Close the connection after each reading (`disconnect`) when
  something else polls the same inverter.
- An `acc32` of 0 is SunSpec's "not implemented", so an energy counter
  that really is at 0 Wh reads `nil`.
- No command-line tool. nmakel's package has one
  (`solaredge-modbus --json`); this gem does not.

## Licence

MIT. The register tables and decoding are nmakel's, under their MIT
licence; both notices are in `LICENSE.txt`.
