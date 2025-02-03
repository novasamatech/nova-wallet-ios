desc "Build the iOS app"
desc "Parameters:"
desc "- 'scheme : <value>' defines scheme to use for build phase"
desc "- 'target : <value>' defines target to build"
desc "- 'configuration : <value>' defines configuration for build"
desc "- 'notification_service_extension : <value>' defines notification service extension to build"
desc "- 'app_identifier : <value>' defines app identifier to build"
desc " "
desc "Example usage: fastlane build_app scheme:'novawallet' target: 'novawallet' configuration: 'Release' notification_service_extension: 'io.novafoundation.novawallet.notificationServiceExtension' app_identifier: 'io.novafoundation.novawallet' "
lane :base_build_app do |options|
  scheme = options[:scheme]
  target = options[:target]
  app_identifier = options[:app_identifier]
  configuration = options[:configuration]
  notification_service_extension = options[:notification_service_extension]
  provisioning_profile = "match AdHoc"
  profile_name = "#{provisioning_profile} #{app_identifier}"
  extension_profile_name = "#{provisioning_profile} #{notification_service_extension}"
  code_sign_identity = "Apple Distribution"
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
    code_sign_identity: code_sign_identity,
    bundle_identifier: app_identifier,
    profile_name: profile_name,
    build_configurations: [configuration]
  )

  update_code_signing_settings(
    use_automatic_signing: false,
    targets: [notification_service_extension],
    code_sign_identity: code_sign_identity,
    bundle_identifier: notification_service_extension,
    profile_name: extension_profile_name,
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
        app_identifier => profile_name,
        extension_identifier => extension_profile_name
      },
      compileBitcode: compile_bitcode
    }
  )
end

