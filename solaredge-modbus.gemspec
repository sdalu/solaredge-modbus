# frozen_string_literal: true

require_relative "lib/solaredge/modbus/version"

Gem::Specification.new do |s|
    s.name        = "solaredge-modbus"
    s.version     = SolarEdge::Modbus::VERSION
    s.authors     = ["Stéphane D'Alu"]
    s.email       = ["sdalu@sdalu.com"]

    s.summary     = "SolarEdge inverters over Modbus TCP"
    s.description = "Read and write a SolarEdge inverter, its meters, " \
                    "batteries and StorEdge settings over Modbus TCP " \
                    "(SunSpec registers): a Ruby port of nmakel's " \
                    "solaredge_modbus. Standard library only."
    s.homepage    = "https://github.com/sdalu/solaredge-modbus"
    s.license     = "MIT"

    s.required_ruby_version = ">= 3.4"

    s.metadata = {
        "homepage_uri" => s.homepage,
        "rubygems_mfa_required" => "true"
    }

    s.files = Dir.chdir(__dir__) do
        Dir["{lib}/**/*", "LICENSE.txt", "README.md"]
            .reject { |f| File.directory?(f) }
    end

    s.require_paths = ["lib"]
end
