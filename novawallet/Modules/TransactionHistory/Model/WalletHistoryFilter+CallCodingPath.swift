extension WalletHistoryFilter {
    func isFit(moduleName: String?, callName: String?) -> Bool {
        guard let moduleName = moduleName, let callName = callName else {
            return false
        }
        let callPath = CallCodingPath(moduleName: moduleName, callName: callName)
        return isFit(callPath: callPath)
    }

    func isFit(callPath: CallCodingPath) -> Bool {
        if callPath.isSubstrateOrEvmTransfer {
            return contains(.transfers)
        } else if callPath.isRewardOrSlashTransfer {
            return contains(.rewardsAndSlashes)
        } else {
            return contains(.extrinsics)
        }
    }
}
