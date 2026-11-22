import Foundation
@testable import novawallet
import Operation_iOS
import SubstrateSdk

final class MockRuntimeFetchOperationFactory {
    struct VersionRequest: Equatable {
        let chainId: ChainModel.Id
        let version: UInt32
        let blockHash: BlockHash?
    }

    let metadataByChainId: ((ChainModel.Id) throws -> RawRuntimeMetadata)?

    /// What the runtime answers when asked for metadata of an exact version; nil stands for "no such version"
    var metadataByVersion: ((ChainModel.Id, UInt32) throws -> RawRuntimeMetadata?)?

    private let mutex = NSLock()
    private var requestsPerChain: [ChainModel.Id: Int] = [:]
    private var storedVersionRequests: [VersionRequest] = []

    var versionRequests: [VersionRequest] {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        return storedVersionRequests
    }

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

    func createMetadataFetchWrapper(
        for chainId: ChainModel.Id,
        connection _: JSONRPCEngine,
        version: UInt32,
        blockHash: BlockHash?
    ) -> CompoundOperationWrapper<RawRuntimeMetadata?> {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        storedVersionRequests.append(VersionRequest(chainId: chainId, version: version, blockHash: blockHash))

        guard let metadataByVersion else {
            return CompoundOperationWrapper.createWithError(CommonError.undefined)
        }

        do {
            return CompoundOperationWrapper.createWithResult(try metadataByVersion(chainId, version))
        } catch {
            return CompoundOperationWrapper.createWithError(error)
        }
    }
}
