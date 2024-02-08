enum SettingsError: Error {
    case biometryAuthAndSystemSettingsOutOfSync
    case walletConnectFailed(Error)
    case web3AlertSettings(Error)
}
