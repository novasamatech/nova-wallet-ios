desc "Build the iOS app"
desc "Parameters:"
desc "- 'scheme : <value>' defines scheme to use for build phase"
desc "- 'target : <value>' defines target to build"
desc "- 'configuration : <value>' defines configuration for build"
desc " "
desc "Example usage: fastlane build_app scheme:'polkadot-app' target: 'polkadot-app' configuration: 'Release' "
lane :base_build_app do |options|
  scheme = options[:scheme]
  target = options[:target]
  configuration = options[:configuration]
  app_identifier = ENV["IOS_BUNDLE_ID"]

  profile_name = ENV["PROVISIONING_PROFILE_SPECIFIER"]
  output_name = scheme
  export_method = "ad-hoc"
  compile_bitcode = false
  xcodeproj_path = "./#{target}.xcodeproj"

  clean_build_artifacts

  increment_build_number(
    build_number: options[:build_number] || ENV["BUILD_NUMBER"],
    xcodeproj: xcodeproj_path
  )

  update_code_signing_settings(
    use_automatic_signing: false,
    targets: [target],
    code_sign_identity: ENV["CODE_SIGN_IDENTITY"],
    bundle_identifier: app_identifier,
    profile_name: profile_name,
    build_configurations: [configuration]
  )

  gym(
    scheme: scheme,
    output_name: output_name,
    configuration: configuration,
    xcargs: "-skipPackagePluginValidation -skipMacroValidation -sdk iphoneos",
    clean: true,
    export_options: {
      method: export_method,
      provisioningProfiles: {
        app_identifier => profile_name
      },
      compileBitcode: compile_bitcode
    }
  )
end

