desc "Build the iOS app"
desc "Parameters:"
desc "- 'scheme : <value>' defines scheme to use for build phase"
desc "- 'target : <value>' defines target to build"
desc "- 'configuration : <value>' defines configuration for build"
desc " "
desc "Example usage: fastlane build_app scheme:'nova-wallet' target: 'nova-wallet' configuration: 'Release' "
lane :base_build_app do |options|
  scheme = options[:scheme]
  target = options[:target]
  configuration = options[:configuration]
  app_identifier = CredentialsManager::AppfileConfig.try_fetch_value(:app_identifier)

  profile_name = ENV["PROVISIONING_PROFILE_SPECIFIER"]
  output_name = scheme
  export_method = "ad-hoc"
  compile_bitcode = false
  xcodeproj_path = "./#{target}.xcodeproj"

  clean_build_artifacts

  increment_build_number(
    build_number: ENV["BUILD_NUMBER"],
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

desc "Prepares certificate and provisioning profile"
lane :prepare_code_signing do |options|
  app_identifier = CredentialsManager::AppfileConfig.try_fetch_value(:app_identifier)
  profile_name = ENV["PROVISIONING_PROFILE_SPECIFIER"]

  # Create keychain for CI
  if is_ci
    create_keychain(
      name: "github_actions_keychain",
      password: ENV["KEYCHAIN_PASSWORD"],
      default_keychain: true,
      unlock: true,
      timeout: 3600,
      add_to_search_list: true,
      lock_when_sleeps: false
    )
  end

  match(
    type: "adhoc",
    app_identifier: app_identifier,
    readonly: true,
    keychain_name: is_ci ? "github_actions_keychain" : nil,
    keychain_password: is_ci ? ENV["KEYCHAIN_PASSWORD"] : nil,
  )
end
