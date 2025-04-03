import Foundation
import SubstrateSdk
import BigInt

extension XcmUni {
    enum NetworkId: Equatable {
        case any
        case byGenesis(Data)
        case polkadot
        case kusama
        case other(RawName, RawValue)
    }

    struct AccountId32: Equatable {
        let network: NetworkId
        let accountId: AccountId
    }

    struct AccountId20: Equatable {
        let network: NetworkId
        let key: AccountId
    }

    struct AccountIndex: Equatable {
        let network: NetworkId
        let index: UInt64
    }

    enum Junction: Equatable {
        case parachain(_ paraId: ParaId)
        case accountId32(AccountId32)
        case accountIndex64(AccountIndex)
        case accountKey20(AccountId20)
        case palletInstance(_ index: UInt8)
        case generalIndex(_ index: BigUInt)
        case generalKey(_ key: Data)
        case onlyChild
        case globalConsensus(NetworkId)
    }

    struct Junctions: Equatable {
        let items: [Junction]

        init(items: [Junction]) {
            self.items = items
        }
    }
}

extension XcmUni.Junctions {
    func appending(components: [XcmUni.Junction]) -> XcmUni.Junctions {
        XcmUni.Junctions(items: items + components)
    }

    func prepending(components: [XcmUni.Junction]) -> XcmUni.Junctions {
        XcmUni.Junctions(items: components + items)
    }

    func lastComponent() -> (XcmUni.Junctions, XcmUni.Junctions) {
        guard let lastJunction = items.last else {
            return (self, XcmUni.Junctions(items: []))
        }

        let remaningItems = Array(items.dropLast())

        return (XcmUni.Junctions(items: remaningItems), XcmUni.Junctions(items: [lastJunction]))
    }
}
