enum SettingsError: Error {
    case biometryAuthAndSystemSettingsOutOfSync
    case walletConnectFailed(Error)
}
