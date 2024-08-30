import Foundation

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

enum MercuryoTransferDataError: Error {
    case invalidData
}
