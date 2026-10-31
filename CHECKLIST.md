# Closing a round on solaredge-modbus

## Gates

- [ ] `bundle exec rake` passes: tests, then RuboCop.
- [ ] `bundle exec rake inverter` prints a status and a power
  (SOLAREDGE_HOST=), if the transport or the inverter table changed:
  a read of the real inverter, read only. Never `write` as a check.

## Documents

- [ ] `README.md`: do the examples still run, and are the known
  shortfalls still the true ones?
- [ ] `DESIGN.md`: did this round depart further from upstream, or make
  a choice it should record?
- [ ] A register or rule changed: does its comment still cite
  upstream's __init__.py at fd3ce7a, or say why it differs?
- [ ] Does the round depart from upstream's behaviour? Then is the
  departure in DESIGN.md's list?

## Release

- [ ] Does `SolarEdge::Modbus::VERSION` in
  `lib/solaredge/modbus/version.rb` move with this round? It is the one
  place the release number is written.
