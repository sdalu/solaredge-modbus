# solaredge-modbus

How it works: README.md. Why it is shaped so: DESIGN.md. What closes a
round: CHECKLIST.md.

Gate: `bundle exec rake`

Ruby style: the `ruby` skill (4-space indentation, double quotes,
`.rubocop.yml` is its rule set).

## Traps

- It started as a port of nmakel/solaredge_modbus @fd3ce7a, but
  upstream is not a contract: diverge where it is wrong or awkward,
  and add the departure to DESIGN.md's list.
- Never write to a real inverter as a check: the writable registers
  change export limits, power control and battery modes. Tests use a
  fake transport.
