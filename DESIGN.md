# Design

## Grown from a port

The library started from nmakel/solaredge_modbus at one commit, `fd3ce7a`,
register for register: names, addresses, types, batches, word orders,
and the decoding rules (16-bit values and strings ignore word order; a
value is decoded over its type's width from the start of its
registers). The table headers cite
`__init__.py` line numbers at that commit, so a register can be
checked against its source. Upstream is where the tables come from,
not a behaviour to match.

It departs from upstream wherever upstream is wrong or awkward. The
departures so far, each one a comparison with upstream's output will
show:

- A not-implemented register reads `nil`. Upstream returns 0, 0.0 or
  `str(False)`, the text `"False"`, so a real zero and a missing value
  look the same, and a missing scale factor (0) scales by 1.
- A signed register (int16, scale factor, int32) holding SunSpec's
  "not implemented" pattern is caught by its bits. Upstream compares
  the signed value, -32768, with 0x8000, never matches, and returns
  -32768.
- A read that fails raises; upstream returns `False`. A device's
  exception reply is not retried, and `read_all` leaves out only the
  batches the device refuses.
- Meter 3 is probed at its `c_sunspec_did`, 0x9e58; upstream probes
  0x9e59, one past it.
- A battery probe the device refuses or leaves unimplemented means no
  battery; upstream counts it as one.
- `read_all` decodes each register at its own address. Upstream's
  decoder advances by the type's width and its offset by the table's
  length, so after battery `event_log` (a uint16 over two registers) it
  reads `event_log_internal` one word early.
- Writing a value its type cannot hold raises `Error`, as upstream's
  `struct.pack` does, rather than being wrapped or truncated.
- Four power-control rows follow SolarEdge's "Power Control Protocol"
  technical note (v1.3) and what an SE7600 sends, where upstream does
  not: `reactive_power_config` is at 0xF104 and
  `reactive_power_response_time` at 0xF106 (upstream: one register
  early), `advanced_power_control_enable` is an Int32 (upstream: a
  uint16), and `cosphi` puts its low word first, as every 32-bit
  value from 0xE000 up does (upstream issue 43, open since 2021).
- A value decodes to its type's Ruby class. Upstream casts each to a
  per-register Python type, which truncated `cosphi` and
  `export_control_site_limit`, both floats, to integers.
- Coded values are named by symbols (`:producing`), not upstream's
  display strings (`"Producing"`). `meters` and `batteries` return
  arrays of devices numbered from 1, not dicts keyed `"Meter1"`; a
  device is built with `number:`, not a 0-based `offset`. Writes
  return `nil`, not a success flag.

Two departures change nothing visible: the retry loop tries the next
attempt after a failed connect, where upstream spends an attempt
reconnecting; and `read_all` picks each register's word order from its
own address, where upstream picks it from the batch's first address,
which agree on every table here.

## SolarEdge, not SunSpec

The codec (`codec.rb`), the register row (`register.rb`) and the
batched reads (`device.rb`) know nothing of SolarEdge. The tables do:
they are SolarEdge's fixed map of SunSpec blocks, plus registers that
are SolarEdge's own (power control at `0xf000`, StorEdge at `0xe000`,
batteries at `0xe100`). A general SunSpec library would walk the model
chain from 40000 and decode float models as well. The vendor-neutral
files are kept separate so that a `sunspec` gem can start from them if
an inverter of another brand arrives, but the gem does not claim more
than the tables give.

## Tried again, or not

An inverter takes one Modbus client at a time, and another may hold it
for a moment; a device can also answer busy. So a read that fails for
a reason that may pass is tried again, after a pause that gives the
other client time to let go (0.5 s, then 1 s), instead of three tries
back to back that meet the same busy slot. A refusal (exception codes
1 to 3) is the device's answer and is final at once, and only a
refusal means "not there": discovery and `read_all` take a busy reply
for what it is, and raise rather than lose a meter or a batch without
a word. Writes are sent once: a write that timed out may have been
applied, and a caller who repeats it should know they are.

## A Modbus client of its own

Modbus TCP is small here: the MBAP header and three function codes (3,
4 and 16), the only ones upstream issues. `transport.rb` and
`frame.rb` together are under 200 lines and tested against a loopback
device, so they are kept instead of taking on `rmodbus`, whose client
is shaped around slaves and which would add a dependency for no new
capability. The transport is injected (`transport:`), so every device
test runs on a register image in memory.

## A reply answers its request, or the connection goes

One connection carries one request at a time, and a reply carries
nothing that says which register it holds. So a reply that comes late
would be read as the answer to the next request, and every value after
it would be one request behind. The transport therefore takes a reply
only if its transaction id, protocol and unit match the request, its
function and lengths agree with what was asked, and it is whole within
the timeout, which runs from the request, not from each byte. Anything
else raises and closes the connection, so whatever is left on the
socket goes with it; the next request opens a new one. The device's
exception reply is the one failure that keeps the connection: it is a
whole, matching answer, and closing on it would have discovery
reconnect for every meter or batch the inverter lacks, on a device
that takes one client at a time.
