import Foundation
import SubstrateSdk
import BigInt

extension XcmUni {
    struct AssetId: Equatable {
        let location: RelativeLocation
    }

    enum WildFungibility: Int {
        case fungible
        case nonFungible
    }

    enum WildMultiasset {
        struct AllOfValue {
            let assetId: AssetId
            let fun: WildFungibility
        }

        case all
        case allOf(AllOfValue)
        case allCounted(UInt32)
        case other(RawName, RawValue)
    }

    typealias AssetInstance = RawValue

    enum Fungibility {
        case fungible(Balance)
        case nonFungible(AssetInstance)
    }

    struct Asset {
        let assetId: AssetId
        let fun: Fungibility

        init(assetId: AssetId, amount: BigUInt) {
            self.assetId = assetId

            // starting from xcmV3 zero amount is prohibited
            fun = .fungible(max(amount, 1))
        }
    }

    typealias Assets = [Asset]

    enum AssetFilter {
        case definite(Assets)
        case wild(WildMultiasset)
    }
}
