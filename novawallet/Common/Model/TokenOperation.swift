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
        case .secrets, .paritySigner:
            return .common(.available)
        case .ledger:
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
        purchaseActions: [PurchaseAction],
        walletType: MetaAccountModelType,
        chainAsset: ChainAsset
    ) -> BuyAvailableCheckResult {
        guard !purchaseActions.isEmpty else {
            return .noBuyOptions
        }

        switch walletType {
        case .secrets, .paritySigner:
            return .common(.available)
        case .ledger:
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
}

enum BuyAvailableCheckResult {
    case common(OperationCheckCommonResult)
    case noBuyOptions
}

enum OperationCheckCommonResult {
    case ledgerNotSupported
    case noSigning
    case available
}
