desc "Distribute App to Firebase"
desc "Parameters:"
desc "- 'release_notes : <value>' to define release notes"
desc "Environment variables:"
desc "- FIREBASE_APP_ID - App ID of the app to distribute"
desc "- CREDENTIAL_FILE_CONTENT - Content of the credentials file for google service account"
desc "- FIREBASE_GROUPS - Groups to distribute the app to (comma separated)"
desc " "
desc "Example usage: fastlane distribute_to_firebase release_notes:'Release notes' google_service_info_plist_path:'path/to/google-service-info.plist'"
lane :distribute_to_firebase do |options|
  app_id = ENV["FIREBASE_APP_ID"]
  service_credentials_json_data = ENV["CREDENTIAL_FILE_CONTENT"]
  groups = ENV["FIREBASE_GROUPS"]
  release_notes = options[:release_notes]

  firebase_app_distribution(
    app: app_id,
    service_credentials_json_data: service_credentials_json_data,
    groups: groups,
    release_notes: release_notes,
    debug: true
  )
end
