import Foundation
@testable import novawallet
import Operation_iOS
import SubstrateSdk

final class MockRuntimeFetchOperationFactory {
    let metadataByChainId: ((ChainModel.Id) throws -> RawRuntimeMetadata)?

    private let mutex = NSLock()
    private var requestsPerChain: [ChainModel.Id: Int] = [:]

    init(rawMetadataDict: [ChainModel.Id: RawRuntimeMetadata]) {
        metadataByChainId = { chainId in
            guard let rawMetadata = rawMetadataDict[chainId] else {
                throw CommonError.undefined
            }

            return rawMetadata
        }
    }

    init(metadataByChainId: ((ChainModel.Id) throws -> RawRuntimeMetadata)? = nil) {
        self.metadataByChainId = metadataByChainId
    }

    func getRequestsCount(for chain: ChainModel.Id) -> Int {
        requestsPerChain[chain] ?? 0
    }
}

extension MockRuntimeFetchOperationFactory: RuntimeFetchOperationFactoryProtocol {
    func createMetadataFetchWrapper(
        for chainId: ChainModel.Id,
        connection _: JSONRPCEngine
    ) -> CompoundOperationWrapper<RawRuntimeMetadata> {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        do {
            requestsPerChain[chainId] = (requestsPerChain[chainId] ?? 0) + 1

            guard let rawMetadata = try metadataByChainId?(chainId) else {
                return CompoundOperationWrapper.createWithError(CommonError.undefined)
            }

            return CompoundOperationWrapper.createWithResult(rawMetadata)
        } catch {
            return CompoundOperationWrapper.createWithError(error)
        }
    }
}
