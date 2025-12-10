private_lane :setup_ci_keychain do
  return unless is_ci

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

desc "Prepares certificate and provisioning profile"
lane :prepare_code_signing do
  begin
    app_identifier = ENV["IOS_BUNDLE_ID"] || raise("Missing IOS_BUNDLE_ID environment variable")
    extension_identifier = ENV["IOS_EXTENSION_BUNDLE_ID"]

    setup_ci_keychain

    # Prepare array of identifiers to fetch profiles for
    identifiers = [app_identifier]
    identifiers << extension_identifier if extension_identifier && !extension_identifier.empty?

    match_config = {
      app_identifier: identifiers,
      readonly: true,
      keychain_name: is_ci ? "github_actions_keychain" : nil,
      keychain_password: is_ci ? ENV["KEYCHAIN_PASSWORD"] : nil
    }

    match(match_config.merge(type: "development"))
    match(match_config.merge(type: "adhoc"))
    match(match_config.merge(type: "appstore"))
  rescue => ex
    UI.error("Failed to prepare code signing: #{ex.message}")
    raise
  end
end

desc "Updates signing data using App Store Connect API"
lane :update_signing_data do
  begin
    api_key_file = ENV["ASC_KEY_BASE64"] || raise("Missing ASC_KEY_BASE64 environment variable")

    setup_ci_keychain

    app_store_connect_api_key(
      key_id: ENV["ASC_KEY_ID"],
      issuer_id: ENV["ASC_ISSUER_ID"],
      key_content: api_key_file,
      is_key_content_base64: true,
      duration: 1200,
      in_house: false
    )

    # Use app_identifier from Matchfile (no need to specify here)
    match_config = {
      readonly: false,
      force_for_new_devices: true,
      keychain_name: is_ci ? "github_actions_keychain" : nil,
      keychain_password: is_ci ? ENV["KEYCHAIN_PASSWORD"] : nil
    }

    match(match_config.merge(type: "development"))
    match(match_config.merge(type: "adhoc"))
    match(match_config.merge(type: "appstore"))

  rescue => ex
    UI.error("Failed to update signing data: #{ex.message}")
    raise
  end
end
