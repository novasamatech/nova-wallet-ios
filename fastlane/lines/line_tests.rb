desc "Run tests"
desc "Parameters:"
desc "- 'scheme : <value>' to define scheme to test"
desc " "
desc "Example usage: fastlane test_build scheme:'novawallet'"
lane :test_build do |options|
  scheme = options[:scheme]

  clear_derived_data
  scan(
    clean: true,
    scheme: scheme,
    workspace: "novawallet.xcworkspace",
    configuration: "Debug",
    xcargs: "EXCLUDED_ARCHS=arm64 -skipPackagePluginValidation -skipMacroValidation ENABLE_TESTABILITY=YES",
    output_directory: "./fastlane/test_output/"
  )
end
