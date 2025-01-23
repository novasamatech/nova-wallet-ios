desc "Distribute App to Firebase"
desc "Parameters:"
desc "- 'release_notes : <value>' to define release notes"
desc " "
desc "Example usage: fastlane distribute_to_firebase release_notes:'Release notes'"
lane :distribute_to_firebase do |options|
  app_id = ENV["FIREBASE_APP_ID"]
  service_credentials_json_data = ENV["CREDENTIAL_FILE_CONTENT"]
  groups = ENV["FIREBASE_GROUPS"]
  release_notes = options[:release_notes]
  googleservice_info_plist_path = 'polkadot-app/GoogleService-Info.plist'

  firebase_app_distribution(
    app: app_id,
    service_credentials_json_data: service_credentials_json_data,
    groups: groups,
    release_notes: release_notes,
    googleservice_info_plist_path: googleservice_info_plist_path,
    debug: true
  )
end
