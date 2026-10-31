# solaredge-modbus

How it works: README.md. Why it is shaped so: DESIGN.md. What closes a
round: CHECKLIST.md.

Gate: `bundle exec rake`

Ruby style: the `ruby` skill (4-space indentation, double quotes,
`.rubocop.yml` is its rule set).

## Traps

- This is a port of nmakel/solaredge_modbus @fd3ce7a. Do not "fix" an
  upstream quirk without saying so in DESIGN.md: matching upstream's
  output is what lets it replace the Python package.
- Never write to a real inverter as a check: the writable registers
  change export limits, power control and battery modes. Tests use a
  fake transport.
