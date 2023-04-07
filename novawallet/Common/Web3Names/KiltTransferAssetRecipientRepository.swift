import RobinHood

typealias TransferAssetRecipientResponse = [Caip19.AssetId: [Web3NameTransferAssetRecipientAccount]]

protocol KiltTransferAssetRecipientRepositoryProtocol {
    func fetchRecipients(
        url: URL,
        hash: String
    ) -> CompoundOperationWrapper<TransferAssetRecipientResponse>
}

final class KiltTransferAssetRecipientRepository: BaseFetchOperationFactory {
    let integrityVerifier: Web3NameIntegrityVerifierProtocol
    let timeout: TimeInterval?

    init(
        integrityVerifier: Web3NameIntegrityVerifierProtocol,
        timeout: TimeInterval? = 60
    ) {
        self.integrityVerifier = integrityVerifier
        self.timeout = timeout
    }

    override func createResultFactory<T>(hash: String?) -> AnyNetworkResultFactory<T> where T: Decodable {
        AnyNetworkResultFactory<T> { data in
            guard let content = String(data: data, encoding: .utf8) else {
                throw KiltTransferAssetRecipientError.corruptedData
            }
            guard let hash = hash else {
                throw KiltTransferAssetRecipientError.verificationFailed
            }
            guard self.integrityVerifier.verify(
                serviceEndpointId: hash,
                serviceEndpointContent: content.trimmingCharacters(in: .whitespacesAndNewlines)
            ) else {
                throw KiltTransferAssetRecipientError.verificationFailed
            }

            do {
                let decoder = JSONDecoder()
                return try decoder.decode(T.self, from: data)
            } catch {
                throw KiltTransferAssetRecipientError.decodingDataFailed(error)
            }
        }
    }
}

extension KiltTransferAssetRecipientRepository: KiltTransferAssetRecipientRepositoryProtocol {
    func fetchRecipients(
        url: URL,
        hash: String
    ) -> CompoundOperationWrapper<TransferAssetRecipientResponse> {
        let fetchOperation: BaseOperation<KiltTransferAssetRecipientResponse> =
            createFetchOperation(from: url, timeout: timeout, hash: hash)

        let mapOperation = ClosureOperation {
            let fetchResult = try fetchOperation.extractNoCancellableResultData()
            return fetchResult.reduce(into: TransferAssetRecipientResponse()) { result, next in
                if let assetId = try? Caip19.AssetId(raw: next.key) {
                    result[assetId] = next.value
                }
            }
        }

        mapOperation.addDependency(fetchOperation)

        return CompoundOperationWrapper(targetOperation: mapOperation, dependencies: [fetchOperation])
    }
}
