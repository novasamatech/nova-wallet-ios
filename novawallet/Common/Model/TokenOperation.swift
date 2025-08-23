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
        case .secrets, .paritySigner, .polkadotVault, .polkadotVaultRoot, .proxied, .multisig:
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
            operationCheckCommonResult.isAvailable
        }
    }
}

enum OperationCheckCommonResult {
    case ledgerNotSupported
    case noSigning
    case noCardSupport(MetaAccountModel)
    case noSellSupport(MetaAccountModel, ChainAsset)
    case noRampActions
    case available

    var isAvailable: Bool {
        if case .available = self {
            true
        } else {
            false
        }
    }
}
