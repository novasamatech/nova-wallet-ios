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
  desc "Parameters:"
  desc "- 'app_identifiers : <value>' defines app identifiers to prepare"
  desc "- 'notification_service_identifier : <value>' defines notification service extension to prepare"
  desc " "
  desc "Example usage: fastlane prepare_code_signing app_identifiers:['one', 'two'] notification_service_identifier: 'one.notificationServiceExtension' "
  lane :prepare_code_signing do |options|
    begin
      app_identifier = options[:app_identifiers]
      notification_service_identifier = options[:notification_service_identifier]
      identifiers = [app_identifier, notification_service_identifier]
      
      setup_ci_keychain
  
      identifiers.each do |identifier|
        match_config = {
          app_identifier: identifier,
          readonly: true,
          keychain_name: is_ci ? "github_actions_keychain" : nil,
          keychain_password: is_ci ? ENV["KEYCHAIN_PASSWORD"] : nil
        }
        
        match(match_config.merge(type: "development"))
        match(match_config.merge(type: "adhoc"))
      end
    rescue => ex
      UI.error("Failed to prepare code signing: #{ex.message}")
      raise
    end
  end
  
  desc "Updates signing data using App Store Connect API"
  desc "Parameters:"
  desc "- 'app_identifiers : <value>' defines app identifiers to update"
  desc "- 'notification_service_identifier : <value>' defines notification service extension to update"
  desc " "
  desc "Example usage: fastlane update_signing app_identifiers:['io.novafoundation.novawallet', 'io.novafoundation.novawallet.notificationServiceExtension'] notification_service_identifier: 'io.novafoundation.novawallet.notificationServiceExtension' "
  lane :update_signing_data do |options|
    begin
      app_identifiers = options[:app_identifiers]
      notification_service_identifier = options[:notification_service_identifier]
      identifiers = [app_identifiers, notification_service_identifier]

      api_key_file = ENV["ASC_KEY_BASE64"] || raise("Missing ASC_KEY_BASE64 environment variable")
      api_key_id = ENV["ASC_KEY_ID"] || raise("Missing ASC_KEY_ID environment variable")
      api_key_issuer_id = ENV["ASC_ISSUER_ID"] || raise("Missing ASC_ISSUER_ID environment variable")
  
      setup_ci_keychain
  
      app_store_connect_api_key(
        key_id: api_key_id,
        issuer_id: api_key_issuer_id,
        key_content: api_key_file,
        is_key_content_base64: true,
        duration: 1200,
        in_house: false
      )
      
      identifiers.each do |identifier|
        match_config = {
          app_identifier: identifier,
          readonly: false,
          force_for_new_devices: true,
          keychain_name: is_ci ? "github_actions_keychain" : nil,
          keychain_password: is_ci ? ENV["KEYCHAIN_PASSWORD"] : nil
        }
    
        match(match_config.merge(type: "development"))
        match(match_config.merge(type: "adhoc"))
      end
    rescue => ex
      UI.error("Failed to update signing data: #{ex.message}")
      raise
    end
  end
  