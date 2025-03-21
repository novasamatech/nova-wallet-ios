enum TokenOperation {
    case send
    case receive
    case buy
}

extension TokenOperation {
    static func checkTransferOperationAvailable() -> TransferAvailableCheckResult {
        true
    }

    static func checkReceiveOperationAvailable(
        walletType: MetaAccountModelType,
        chainAsset: ChainAsset
    ) -> ReceiveAvailableCheckResult {
        switch walletType {
        case .secrets, .paritySigner, .polkadotVault, .proxied:
            return .common(.available)
        case .ledger, .genericLedger:
            if let assetRawType = chainAsset.asset.type, case .orml = AssetType(rawValue: assetRawType) {
                return .common(.ledgerNotSupported)
            } else {
                return .common(.available)
            }

        case .watchOnly:
            return .common(.noSigning)
        }
    }

    static func checkBuyOperationAvailable(
        rampActions: [RampAction],
        walletType: MetaAccountModelType,
        chainAsset: ChainAsset
    ) -> RampAvailableCheckResult {
        guard !rampActions.isEmpty else {
            return .noRampOptions
        }

        switch walletType {
        case .secrets, .paritySigner, .polkadotVault, .proxied:
            return .common(.available)
        case .ledger, .genericLedger:
            if let assetRawType = chainAsset.asset.type, case .orml = AssetType(rawValue: assetRawType) {
                return .common(.ledgerNotSupported)
            } else {
                return .common(.available)
            }
        case .watchOnly:
            return .common(.noSigning)
        }
    }

    static func checkSellOperationAvailable(
        rampActions: [RampAction],
        walletType: MetaAccountModelType,
        chainAsset: ChainAsset
    ) -> RampAvailableCheckResult {
        guard !rampActions.isEmpty else {
            return .noRampOptions
        }

        switch walletType {
        case .secrets, .paritySigner, .polkadotVault, .proxied:
            return .common(.available)
        case .ledger, .genericLedger:
            if let assetRawType = chainAsset.asset.type, case .orml = AssetType(rawValue: assetRawType) {
                return .common(.ledgerNotSupported)
            } else {
                return .common(.available)
            }
        case .watchOnly:
            return .common(.noSigning)
        }
    }
}

typealias TransferAvailableCheckResult = Bool

enum ReceiveAvailableCheckResult {
    case common(OperationCheckCommonResult)

    var available: Bool {
        switch self {
        case let .common(operationCheckCommonResult):
            return operationCheckCommonResult == .available
        }
    }
}

enum RampAvailableCheckResult {
    case common(OperationCheckCommonResult)
    case noRampOptions

    var available: Bool {
        switch self {
        case let .common(operationCheckCommonResult):
            return operationCheckCommonResult == .available
        case .noRampOptions:
            return false
        }
    }
}

enum OperationCheckCommonResult {
    case ledgerNotSupported
    case noSigning
    case available
}
