# frozen_string_literal: true

require "rake/testtask"
require "rubocop/rake_task"

Rake::TestTask.new do |task|
    task.libs << "lib" << "test"
    task.pattern = "test/**/*_test.rb"
end

RuboCop::RakeTask.new

task default: %i[test rubocop]

desc "Read a real inverter's status and AC power, read only " \
     "(SOLAREDGE_HOST=, SOLAREDGE_PORT= default 1502)"
task :inverter do
    $LOAD_PATH.unshift(File.expand_path("lib", __dir__))
    require "solaredge/modbus"
    inverter = SolarEdge::Modbus::Inverter.new(
        host: ENV.fetch("SOLAREDGE_HOST"),
        port: Integer(ENV.fetch("SOLAREDGE_PORT", "1502"))
    )
    begin
        power = inverter.read(:power_ac) *
                (10.0**inverter.read(:power_ac_scale))
        puts "status #{inverter.read(:status)}, #{power.round(1)} W"
    ensure
        inverter.disconnect
    end
end
