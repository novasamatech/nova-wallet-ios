desc "Run tests"
desc "Parameters:"
desc "- 'scheme : <value>' to define scheme to test"
desc "- 'debug : true/false' to enable verbose logging for troubleshooting build failures (especially Crashlytics issues)"
desc " "
desc "Example usage: fastlane test_build scheme:'novawallet'"
desc "Example usage: fastlane test_build scheme:'novawallet' debug:true"
lane :test_build do |options|
  scheme = options[:scheme]
  debug_mode = options[:debug] == true || options[:debug] == 'true'

  # Base scan parameters for running tests
  scan_params = {
    clean: true,
    cloned_source_packages_path: 'source_packages',
    scheme: scheme,
    project: "novawallet.xcodeproj",
    configuration: "Debug",
    xcargs: "-skipPackagePluginValidation -skipMacroValidation RUN_IN_CI=#{ENV['RUN_IN_CI']}",
    output_directory: "./fastlane/test_output/",
    disable_concurrent_testing: true
  }

  # DEBUG MODE: Helps diagnose build failures (Crashlytics, dependencies, etc.)
  # Enables: verbose logs, saves build artifacts, continues on failure
  # Use when: normal builds fail with unclear errors
  if debug_mode
    UI.important "🔍 Debug mode enabled - verbose logging and artifacts will be collected"
    scan_params.merge!({
      buildlog_path: "./fastlane/build_logs/",  # Saves xcodebuild logs for analysis
      xcpretty_args: "--verbose",               # Shows full xcodebuild output
      fail_build: false                          # Continues to collect maximum info even on failure
    })
  end

  scan(scan_params)
end

desc "Run Swift package tests"
desc "Parameters:"
desc "- 'package : <value>' to define the package in Packages to test"
desc "- 'test_target : <value>' to define the test target to run"
desc "- 'derived_data_path : <value>' to define the derived data directory"
desc " "
desc "Example usage: fastlane test_package package:'NovaAuth' test_target:'NovaAuthTests'"
lane :test_package do |options|
  package = options[:package]

  scan(
    package_path: "Packages/#{package}",
    scheme: package,
    only_testing: options[:test_target],
    derived_data_path: options[:derived_data_path],
    output_directory: "./fastlane/test_output/",
    prelaunch_simulator: true,
    ensure_devices_found: true,
    xcargs: "-destination-timeout 120"
  )
end
