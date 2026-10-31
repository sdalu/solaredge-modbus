# Design

## A port, not a rewrite

The library follows nmakel/solaredge_modbus at one commit, `fd3ce7a`,
register for register: names, addresses, types, batches, word orders,
and the decoding rules, including those of the pymodbus 3.5 coders it
calls (16-bit values and strings ignore word order; a value is decoded
over its type's width from the start of its registers). Comments cite
`__init__.py` line numbers at that commit, so a register can be
checked against its source.

Where upstream is wrong, this is not. Each departure is one a
comparison with upstream's output will show:

- A signed register (int16, scale factor, int32) holding SunSpec's
  "not implemented" pattern reads 0. Upstream compares the signed
  value, -32768, with 0x8000, never matches, and returns -32768.
- A not-implemented string reads `""`; upstream returns `str(False)`,
  the text `"False"`.
- Meter 3 is probed at its `c_sunspec_did`, 0x9e58; upstream probes
  0x9e59, one past it.
- A battery probe that cannot be read means no battery; upstream counts
  it as one (`False != 255`).
- `read_all` decodes each register at its own address. Upstream's
  decoder advances by the type's width and its offset by the table's
  length, so after battery `event_log` (a uint16 over two registers) it
  reads `event_log_internal` one word early.
- Writing a value its type cannot hold raises `Error`, as upstream's
  `struct.pack` does, rather than being wrapped or truncated.

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
socket goes with it; the next request opens a new one.
