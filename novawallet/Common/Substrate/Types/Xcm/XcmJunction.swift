import Foundation
import BigInt

extension Xcm {
    enum NetworkId: Encodable {
        case any
        case named(_ data: [Data])
        case polkadot
        case kusama
    }

    enum Junction {
        case parachain(_ paraId: UInt32)
        case accountId32(_ network: NetworkId, accountId: AccountId)
        case accountIndex64(_ network: NetworkId, index: UInt64)
        case accountKey20(_ network: NetworkId, accountId: AccountId)
        case palletInstance(_ index: UInt8)
        case generalIndex(_ index: BigUInt)
        case generalKey(_ key: Data)
        case onlyChild
        case plurality
    }

    enum Junctions {
        case here
        case x1(Junction)
        case x2(Junction, Junction)
        case x3(Junction, Junction, Junction)
        case x4(Junction, Junction, Junction, Junction)
        case x5(Junction, Junction, Junction, Junction, Junction)
        case x6(Junction, Junction, Junction, Junction, Junction, Junction)
        case x7(Junction, Junction, Junction, Junction, Junction, Junction, Junction)
        case x8(Junction, Junction, Junction, Junction, Junction, Junction, Junction, Junction)
    }
}
