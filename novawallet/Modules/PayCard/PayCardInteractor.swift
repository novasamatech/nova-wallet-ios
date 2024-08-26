import BigInt
import Foundation

struct MercuryoTransferData: Decodable {
    let id: String
    let flowId: String
    let amount: AmountDecimal
    let currency: String
    let network: String
    let address: AccountAddress

    enum CodingKeys: String, CodingKey {
        case id
        case flowId = "flow_id"
        case amount
        case currency
        case network
        case address
    }
}

struct MercuryoTransferModel {
    let chainAsset: ChainAsset
    let amount: Decimal
    let address: AccountAddress
}

final class PayCardInteractor {
    weak var presenter: PayCardInteractorOutputProtocol?

    let chainRegistry: ChainRegistryProtocol

    init(chainRegistry: ChainRegistryProtocol) {
        self.chainRegistry = chainRegistry
    }
}

extension PayCardInteractor: PayCardInteractorInputProtocol {
    func process(_ data: Data) {
        guard
            let transferData = try? decode(from: data),
            let chain = chainRegistry.getChain(for: KnowChainId.polkadot),
            let asset = chain.utilityAsset()
        else {
            return
        }

        let transferModel = MercuryoTransferModel(
            chainAsset: .init(chain: chain, asset: asset),
            amount: transferData.amount.decimalValue,
            address: transferData.address
        )

        presenter?.didReceive(transferModel)
    }
}

private extension PayCardInteractor {
    func decode(from data: Data) throws -> MercuryoTransferData {
        let decoder = JSONDecoder()

        let transferData = try decoder.decode(
            MercuryoTransferData.self,
            from: data
        )

        return transferData
    }
}
