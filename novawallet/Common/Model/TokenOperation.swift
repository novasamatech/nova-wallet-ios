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
        case .secrets, .paritySigner, .polkadotVault, .polkadotVaultRoot, .proxied:
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

    static func checkRampOperationsAvailable(
        for rampActions: [RampAction],
        rampType: RampActionType,
        walletType: MetaAccountModelType,
        chainAsset: ChainAsset
    ) -> RampAvailableCheckResult {
        let filteredActions = rampActions.filter { $0.type == rampType }

        guard !filteredActions.isEmpty else {
            return .noRampOptions
        }

        return switch walletType {
        case .secrets, .paritySigner, .polkadotVault, .polkadotVaultRoot, .proxied:
            .common(.available)
        case .ledger, .genericLedger:
            if let assetRawType = chainAsset.asset.type, case .orml = AssetType(rawValue: assetRawType) {
                .common(.ledgerNotSupported)
            } else {
                .common(.available)
            }
        case .watchOnly:
            .common(.noSigning)
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
