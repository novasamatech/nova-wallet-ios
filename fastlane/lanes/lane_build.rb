desc "Build the iOS app"
desc "Parameters:"
desc "- 'scheme : <value>' defines scheme to use for build phase"
desc "- 'target : <value>' defines target to build"
desc "- 'configuration : <value>' defines configuration for build"
desc "- 'debug : true/false' to enable verbose logging for troubleshooting build failures"
desc " "
desc "Example usage: fastlane build_app scheme:'novawallet' target: 'novawallet' configuration: 'Release' "
desc "Example usage: fastlane base_build_app scheme:'novawallet' target: 'novawallet' configuration: 'Debug' debug:true"
lane :base_build_app do |options|
  scheme = options[:scheme]
  target = options[:target]
  configuration = options[:configuration]
  debug_mode = options[:debug] == true || options[:debug] == 'true'
  app_identifier = ENV["IOS_BUNDLE_ID"]
  extension_identifier = ENV["IOS_EXTENSION_BUNDLE_ID"]

  profile_name = ENV["PROVISIONING_PROFILE_SPECIFIER"]
  extension_profile_name = ENV["EXTENSION_PROVISIONING_PROFILE_SPECIFIER"]
  output_name = scheme
  export_method = options[:export_method] || ENV["EXPORT_METHOD"] || "app-store"
  compile_bitcode = false
  xcodeproj_path = "./#{target}.xcodeproj"
  extension_target = "NovaPushNotificationServiceExtension"

  clean_build_artifacts

  increment_build_number(
    build_number: options[:build_number] || ENV["BUILD_NUMBER"],
    xcodeproj: xcodeproj_path
  )

  # Update code signing for main app
  update_code_signing_settings(
    use_automatic_signing: false,
    targets: [target],
    code_sign_identity: ENV["CODE_SIGN_IDENTITY"],
    bundle_identifier: app_identifier,
    profile_name: profile_name,
    build_configurations: [configuration]
  )

  # Update code signing for notification extension (if configured)
  if extension_identifier && !extension_identifier.empty?
    update_code_signing_settings(
      use_automatic_signing: false,
      targets: [extension_target],
      code_sign_identity: ENV["CODE_SIGN_IDENTITY"],
      bundle_identifier: extension_identifier,
      profile_name: extension_profile_name,
      build_configurations: [configuration]
    )
  end

  # Prepare provisioning profiles mapping
  provisioning_profiles = { app_identifier => profile_name }
  if extension_identifier && !extension_identifier.empty?
    provisioning_profiles[extension_identifier] = extension_profile_name
  end

  # Base gym parameters
  gym_params = {
    scheme: scheme,
    output_name: output_name,
    configuration: configuration,
    xcargs: "-skipPackagePluginValidation -skipMacroValidation RUN_IN_CI=#{ENV['RUN_IN_CI']}",
    clean: true,
    cloned_source_packages_path: 'source_packages',
    export_options: {
      method: export_method,
      provisioningProfiles: provisioning_profiles,
      compileBitcode: compile_bitcode
    }
  }

  # DEBUG MODE: Helps diagnose build failures (signing, dependencies, etc.)
  # Enables: verbose logs, saves build artifacts
  # Use when: normal builds fail with unclear errors
  if debug_mode
    UI.important "🔍 Debug mode enabled - verbose logging and artifacts will be collected"
    gym_params.merge!({
      buildlog_path: "./fastlane/build_logs/",  # Saves xcodebuild logs for analysis
      disable_xcpretty: true                     # Shows full xcodebuild output
    })
  end

  gym(gym_params)
end
