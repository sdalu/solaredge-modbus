# solaredge-modbus

Read and write a SolarEdge inverter over Modbus TCP: the inverter
itself, the meters and batteries attached to it, and its StorEdge
settings, through the SunSpec registers SolarEdge exposes. A Ruby port
of [nmakel/solaredge_modbus](https://github.com/nmakel/solaredge_modbus)
at commit `fd3ce7a` (2025-01-08): same register tables, same names, same
decoding, quirks included.

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
- A register the device marks as not implemented decodes to `0`, `0.0`
  or the string `"False"` (upstream's `vtype(False)`).
- A read that fails three times returns `false`; it does not raise.
  Connection and protocol failures inside a try are
  `SolarEdge::Modbus::Error`.
- `Device#write(name, value)` encodes and writes one register. Nothing
  here has been written to a real inverter: writes are checked only
  against the framing tests.
- A device connects on its first read and stays connected until
  `disconnect`. `Inverter#meters` and `#batteries` share the
  inverter's connection.
- `Meter.new(offset: 0..2, host:, port:)`, `Battery.new(offset: 0..1,
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
- Upstream's quirks are kept, not fixed: an `acc32` of exactly 0 reads
  as "not implemented" (0), a battery probe that fails counts as a
  battery present, and meter 3's probe address is one past the pattern.
- No command-line tool yet. nmakel's package has one
  (`solaredge-modbus --json`) that casper still calls.

## Licence

MIT. The register tables and decoding are nmakel's, under their MIT
licence; both notices are in `LICENSE.txt`.
