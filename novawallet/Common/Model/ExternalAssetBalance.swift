import Foundation
import BigInt
import Operation_iOS
import Foundation_iOS

struct ExternalAssetBalance: Equatable, Identifiable {
    enum BalanceType: String {
        case crowdloan
        case nominationPools
        case unknown

        init(rawType: String) {
            if let knownType = Self(rawValue: rawType) {
                self = knownType
            } else {
                self = .unknown
            }
        }
    }

    let identifier: String
    let chainAssetId: ChainAssetId
    let accountId: AccountId
    let amount: BigUInt
    let type: BalanceType
    let subtype: String?
    let param: String?
}

struct ExternalBalanceAssetGroupId: Equatable, Hashable {
    let chainAssetId: ChainAssetId
    let type: ExternalAssetBalance.BalanceType

    var stringValue: String {
        chainAssetId.stringValue + "-" + type.rawValue
    }
}

extension Array where Element == ExternalAssetBalance {
    func groupByAssetType() -> [ExternalBalanceAssetGroupId: BigUInt] {
        reduce(into: [ExternalBalanceAssetGroupId: BigUInt]()) { accum, balance in
            let group = ExternalBalanceAssetGroupId(chainAssetId: balance.chainAssetId, type: balance.type)

            let previousAmount = accum[group] ?? 0
            accum[group] = previousAmount + balance.amount
        }
    }
}

extension ExternalAssetBalance.BalanceType {
    var lockTitle: LocalizableResource<String> {
        switch self {
        case .crowdloan:
            return LocalizableResource { R.string(preferredLanguages: $0.rLanguages).localizable.tabbarCrowdloanTitle() }
        case .nominationPools:
            return LocalizableResource {
                R.string(preferredLanguages: $0.rLanguages).localizable.stakingTypeNominationPool()
            }
        case .unknown:
            return LocalizableResource { R.string(preferredLanguages: $0.rLanguages).localizable.commonUnknown() }
        }
    }
}
