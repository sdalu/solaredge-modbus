# frozen_string_literal: true

require "open3"
require "rbconfig"

require "test_helper"

# Every file of the library works when required on its own: each
# constant of SolarEdge::Modbus its code names (not its comments, not
# what it defines itself) is defined once it is loaded.
class SolarEdgeRequireTest < Minitest::Test
    LIB = File.expand_path("../lib", __dir__)
    NAMES = SolarEdge::Modbus.constants.map(&:to_s).freeze

    Dir[File.join(LIB, "solaredge/modbus/**/*.rb")].each do |path|
        feature = path.delete_prefix("#{LIB}/").delete_suffix(".rb")
        define_method("test_#{feature.tr("/", "_")}_stands_alone") do
            assert_empty missing_after(feature, used_names(path))
        end
    end

    private

    def used_names(path)
        code = File.read(path).gsub(/^\s*#.*$/, "")
        defined = code.scan(/^\s*(?:module|class)\s+(\w+)/).flatten
        (code.scan(/\b[A-Z]\w*/).uniq & NAMES) - defined
    end

    def missing_after(feature, names)
        script = "require #{feature.dump}; " \
                 "puts #{names.inspect}.reject { " \
                 "SolarEdge::Modbus.const_defined?(it) }"
        out, status = Open3.capture2e(RbConfig.ruby, "-I", LIB, "-e", script)
        assert status.success?, out
        out.split
    end
end
