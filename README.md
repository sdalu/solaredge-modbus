# solaredge-modbus

Read and write a SolarEdge inverter over Modbus TCP: the inverter
itself, the meters and batteries attached to it, and its StorEdge
settings, through the SunSpec registers SolarEdge exposes. A Ruby port
of [nmakel/solaredge_modbus](https://github.com/nmakel/solaredge_modbus)
at commit `fd3ce7a` (2025-01-08): same register tables, same names, same
decoding, without upstream's bugs (DESIGN.md lists them).

It needs only Ruby's standard library (Ruby 3.4).

## Use

```ruby
require "solaredge/modbus"

inverter = SolarEdge::Modbus::Inverter.new(host: "192.168.1.30",
                                           port: 1502)
begin
    power = inverter.read(:power_ac) * 10.0**inverter.read(:power_ac_scale)
    puts "status #{inverter.read(:status)}, #{power} W"

    inverter.read_all.each { |name, value| puts "#{name}: #{value}" }

    inverter.meters.each do |name, meter|
        net = meter.read(:power) * 10.0**meter.read(:power_scale)
        puts "#{name}: #{net} W at the grid connection"
    end
    inverter.batteries.each { |name, b| puts "#{name}: #{b.read(:soe)} %" }
ensure
    inverter.disconnect
end
```

- `Device#read(name)` reads one register and decodes it; `read_all`
  reads every register in as few requests as upstream's batches allow
  and returns `{ name => value }`. Register names are upstream's: see
  `lib/solaredge/modbus/registers/`.
- Values are raw: a quantity and its `_scale` register are read
  separately, and the value is `quantity * 10**scale`.
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
- `Device#write(name, value)` encodes and writes one register, and
  raises `Error` for a value its type cannot hold (an Integer in range
  for integer registers, a number within float32 for float ones).
  Nothing here has been written to a real inverter: writes are checked
  only against the framing tests.
- A device connects on its first read and stays connected until
  `disconnect`. `Inverter#meters` and `#batteries` share the
  inverter's connection.
- `Meter.new(offset: 0..2, host:, port:)` (another offset raises
  `IndexError`), `Battery.new(offset: 0..1,
  …)` and `StorEdge.new(…)` build a device directly; `transport:` takes
  any object answering `connected?`, `connect`, `close`,
  `read_registers` and `write_registers`, which is how the tests run
  without a socket.

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
