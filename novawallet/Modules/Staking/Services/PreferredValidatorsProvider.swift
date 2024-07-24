import Foundation
import Operation_iOS

struct PreferredValidatorsProviderModel {
    let preferred: [AccountId]
    let excluded: Set<AccountId>
}

protocol PreferredValidatorsProviding {
    func createPreferredValidatorsWrapper(
        for chain: ChainModel
    ) -> CompoundOperationWrapper<PreferredValidatorsProviderModel?>
}

final class PreferredValidatorsProvider: BaseFetchOperationFactory {
    typealias Store = [ChainModel.Id: [AccountAddress]]

    struct RemoteModel: Decodable {
        let preferred: Store?
        let excluded: Store?
    }

    @Atomic(defaultValue: nil)
    private var remoteModel: RemoteModel?

    let remoteUrl: URL
    let timeout: TimeInterval

    init(remoteUrl: URL, timeout: TimeInterval = 30) {
        self.remoteUrl = remoteUrl
        self.timeout = timeout
    }

    private func convert(addresses: [AccountAddress], chainFormat: ChainFormat) throws -> [AccountId] {
        try addresses.compactMap { try $0.toAccountId(using: chainFormat) }
    }

    private func createLocalModel(
        for chain: ChainModel,
        remoteModel: RemoteModel
    ) throws -> PreferredValidatorsProviderModel {
        let preferred = try convert(
            addresses: remoteModel.preferred?[chain.chainId] ?? [],
            chainFormat: chain.chainFormat
        )

        let prohibited = try convert(
            addresses: remoteModel.excluded?[chain.chainId] ?? [],
            chainFormat: chain.chainFormat
        )

        return .init(preferred: preferred, excluded: Set(prohibited))
    }
}

extension PreferredValidatorsProvider: PreferredValidatorsProviding {
    func createPreferredValidatorsWrapper(
        for chain: ChainModel
    ) -> CompoundOperationWrapper<PreferredValidatorsProviderModel?> {
        if let remoteModel, let localModel = try? createLocalModel(for: chain, remoteModel: remoteModel) {
            return CompoundOperationWrapper.createWithResult(localModel)
        }

        let fetchOperation: BaseOperation<RemoteModel> = createFetchOperation(
            from: remoteUrl,
            shouldUseCache: false,
            timeout: timeout
        )

        let mapOperation = ClosureOperation<PreferredValidatorsProviderModel?> {
            guard let remoteModel = try? fetchOperation.extractNoCancellableResultData() else {
                return nil
            }

            self.remoteModel = remoteModel

            return try? self.createLocalModel(for: chain, remoteModel: remoteModel)
        }

        mapOperation.addDependency(fetchOperation)

        return CompoundOperationWrapper(targetOperation: mapOperation, dependencies: [fetchOperation])
    }
}
