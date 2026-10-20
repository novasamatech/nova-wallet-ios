import Foundation
import NovaAnalytics

extension MetaAccountModelType {
    var analyticsWalletType: AnalyticsWalletType {
        switch self {
        case .secrets: .secrets
        case .watchOnly: .watchOnly
        case .paritySigner: .paritySigner
        case .ledger: .ledger
        case .polkadotVault: .polkadotVault
        case .proxied: .proxied
        case .genericLedger: .genericLedger
        case .multisig: .multisig
        }
    }
}

extension OperationCheckCommonResult {
    var subtensorBlockedReason: StakingBlockedReason? {
        switch self {
        case .ledgerNotSupported:
            .ledger
        case let .noSubtensorStakingSupport(walletType):
            walletType == .multisig ? .multisigUnsupported : .proxy
        case .noSigning:
            .watchOnly
        case .noCardSupport, .noSellSupport, .noGiftSupport, .noRampActions, .available:
            nil
        }
    }
}

extension SubtensorStakeTarget {
    var analyticsTarget: StakingAnalyticsTarget {
        isRoot ? .root : .subnet
    }

    var analyticsNetuid: AnalyticsContentValue? {
        .netuid(netuid)
    }
}
