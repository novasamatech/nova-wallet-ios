desc "Run tests"
desc "Parameters:"
desc "- 'scheme : <value>' to define scheme to test"
desc " "
desc "Example usage: fastlane test_build scheme:'nova-wallet'"
lane :test_build do |options|
  scheme = options[:scheme]

  clear_derived_data
  scan(
    clean: true,
    scheme: scheme,
    workspace: "nova-wallet.xcworkspace",
    configuration: "DevCI",
    xcargs: "EXCLUDED_ARCHS=arm64 -skipPackagePluginValidation -skipMacroValidation",
    output_directory: "./fastlane/test_output/"
  )
end
