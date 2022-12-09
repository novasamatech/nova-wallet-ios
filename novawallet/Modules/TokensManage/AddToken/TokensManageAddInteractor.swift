import UIKit
import SubstrateSdk
import BigInt

final class TokensManageAddInteractor {
    weak var presenter: TokensManageAddInteractorOutputProtocol?

    let chain: ChainModel
    let connection: JSONRPCEngine
    let queryFactory: EvmQueryContractMessageFactoryProtocol

    private var pendingQueryId: UInt16?

    init(chain: ChainModel, connection: JSONRPCEngine, queryFactory: EvmQueryContractMessageFactoryProtocol) {
        self.chain = chain
        self.connection = connection
        self.queryFactory = queryFactory
    }

    private func handleDetailsResponse(_ results: [Result<JSON, Error>], contractAddress: AccountAddress) {
        let symbol = (try? results[1].get())?.stringValue
        let decimals: UInt8?

        if let decimalsString = (try? results[2].get())?.stringValue {
            decimals = BigUInt.fromHexString(decimalsString).map { UInt8($0) }
        } else {
            decimals = nil
        }

        let details = EvmContractMetadata(symbol: symbol, decimals: decimals)

        presenter?.didReceiveDetails(details, for: contractAddress)
    }
}

extension TokensManageAddInteractor: TokensManageAddInteractorInputProtocol {
    func provideDetails(for address: AccountAddress) {
        if let pendingQueryId = pendingQueryId {
            self.pendingQueryId = nil
            connection.cancelForIdentifier(pendingQueryId)
        }

        let batchId = UUID().uuidString

        do {
            let symbolCall = try queryFactory.erc20Symbol(from: address)
            let decimalsCall = try queryFactory.erc20Decimals(from: address)

            let calls = [symbolCall, decimalsCall]

            for call in calls {
                let params = EvmQueryMessage.Params(call: call, block: .latest)
                try connection.addBatchCallMethod(EvmQueryMessage.method, params: params, batchId: batchId)
            }

            pendingQueryId = try connection.submitBatch(for: batchId) { [weak self] results in
                DispatchQueue.main.async {
                    guard self?.pendingQueryId != nil else {
                        return
                    }

                    self?.pendingQueryId = nil

                    guard calls.count == results.count else {
                        return
                    }

                    self?.handleDetailsResponse(results, contractAddress: address)
                }
            }
        } catch {
            presenter?.didReceiveError(.evmDetailsFetchFailed(error))
        }
    }

    func processPriceId(from urlString: String) {

    }

    func save(newToken: EvmTokenAddRequest) {

    }
}
