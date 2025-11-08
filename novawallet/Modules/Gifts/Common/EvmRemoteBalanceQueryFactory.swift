import Foundation
import Operation_iOS
import BigInt

protocol EvmRemoteBalanceQueryFactoryProtocol {
    func fetchBalance(
        for address: AccountAddress,
        chainId: ChainModel.Id
    ) -> CompoundOperationWrapper<BigUInt>
}

final class EvmRemoteBalanceQueryFactory {
    private let chainRegistry: ChainRegistryProtocol

    init(chainRegistry: ChainRegistryProtocol) {
        self.chainRegistry = chainRegistry
    }
}

extension EvmRemoteBalanceQueryFactory: EvmRemoteBalanceQueryFactoryProtocol {
    func fetchBalance(
        for address: AccountAddress,
        chainId: ChainModel.Id
    ) -> CompoundOperationWrapper<BigUInt> {
        let operation = AsyncClosureOperation<BigUInt> { completion in
            let connection = try self.chainRegistry.getConnectionOrError(for: chainId)

            let params = EvmBalanceMessage.Params(holder: address, block: .latest)

            _ = try connection.callMethod(
                EvmBalanceMessage.method,
                params: params,
                options: .init(resendOnReconnect: true)
            ) { (result: Result<String, Error>) in
                switch result {
                case let .success(balanceString):
                    guard let balanceValue = BigUInt.fromHexString(balanceString) else {
                        completion(.failure(EvmRemoteBalanceQueryError.unexpectedBalanceValue))
                        return
                    }

                    completion(.success(balanceValue))
                case let .failure(error):
                    completion(.failure(error))
                }
            }
        }

        return CompoundOperationWrapper(targetOperation: operation)
    }
}

enum EvmRemoteBalanceQueryError: Error {
    case unexpectedBalanceValue
}
