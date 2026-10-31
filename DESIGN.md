# Design

## A port, not a rewrite

The library follows nmakel/solaredge_modbus at one commit, `fd3ce7a`,
register for register: names, addresses, types, batches, word orders,
and the decoding rules including the odd ones (a not-implemented string
reads as `"False"`, an `acc32` of 0 is not implemented, a failed battery
probe counts as present). Comments cite `__init__.py` line numbers at
that commit, so a register can be checked against its source. Keeping
upstream's behaviour means its output and this one's can be compared
key for key, which is what replacing the Python package needs.

Two departures, neither visible from outside. The retry loop tries the
next attempt after a failed connect, where upstream spends an attempt
reconnecting. `read_all` picks each register's word order from its own
address, where upstream picks it from the batch's first address; on
every table here the two agree.

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
4 and 16), the only ones upstream issues. `transport.rb` is about 130
lines and tested against a loopback server, so it is kept instead of
taking on `rmodbus`, whose client is shaped around slaves and which
would add a dependency for no new capability. The transport is
injected (`transport:`), so every device test runs on a register image
in memory.

## Extracted from ClimatControl

The code was written inside ClimatControl as `ClimatControl::SolarEdge`
(its energy provider reads production and the meter's net power from
it) and moved here unchanged except for the namespace, so that MadHouse,
through casper, can drop the Python package.
