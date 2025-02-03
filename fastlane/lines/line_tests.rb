desc "Run tests"
desc "Parameters:"
desc "- 'scheme : <value>' to define scheme to test"
desc " "
desc "Example usage: fastlane test_build scheme:'novawallet'"
lane :test_build do |options|
  scheme = options[:scheme]
  configuration = options[:configuration]

  clear_derived_data
  scan(
    clean: true,
    scheme: scheme,
    workspace: "novawallet.xcworkspace",
    configuration: configuration,
    xcargs: "EXCLUDED_ARCHS=arm64 -skipPackagePluginValidation -skipMacroValidation",
    output_directory: "./fastlane/test_output/"
  )
end
