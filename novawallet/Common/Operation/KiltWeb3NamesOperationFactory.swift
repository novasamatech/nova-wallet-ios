import Foundation
import BigInt
import RobinHood
import SubstrateSdk

protocol KiltWeb3NamesOperationFactoryProtocol {
    func search(
        name: String,
        connection: JSONRPCEngine
    ) -> CompoundOperationWrapper<KiltNameResponse>
}

final class KiltWeb3NamesOperationFactory: KiltWeb3NamesOperationFactoryProtocol {
    enum RPCMethods {
        static let querySearchName = "DidV2_queryByWeb3Name"
    }

    func search(
        name: String,
        connection: JSONRPCEngine
    ) -> CompoundOperationWrapper<KiltNameResponse> {
        let operation: JSONRPCOperation<KiltNameRequest, KiltNameResponse> = JSONRPCOperation(
            engine: connection,
            method: RPCMethods.querySearchName,
            parameters: KiltNameRequest(name: name)
        )

        return CompoundOperationWrapper(targetOperation: operation)
    }
}

struct KiltNameResponse: Codable {
    let did: String
    let accountId: AccountId
    @StringCodable var balance: BigUInt
    let hash: String
    let blockNumber: BlockNumber

    enum CodingKeys: String, CodingKey {
        case did = "DidIdentifier"
        case accountId = "AccountId"
        case balance = "Balance"
        case hash = "Hash"
        case blockNumber = "BlockNumber"
    }
}

struct KiltNameRequest: Codable {
    let name: String
}
