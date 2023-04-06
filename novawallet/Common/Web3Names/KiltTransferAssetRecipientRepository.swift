import RobinHood

typealias TransferAssetRecipientResponse = [Caip19.AssetId: [KiltTransferAssetRecipientAccount]]

protocol KiltTransferAssetRecipientRepositoryProtocol {
    func fetchRecipients(
        url: URL,
        hash: String
    ) -> CompoundOperationWrapper<TransferAssetRecipientResponse>
}

final class KiltTransferAssetRecipientRepository {
    let integrityVerifier: Web3NameIntegrityVerifierProtocol

    init(integrityVerifier: Web3NameIntegrityVerifierProtocol) {
        self.integrityVerifier = integrityVerifier
    }
}

extension KiltTransferAssetRecipientRepository: KiltTransferAssetRecipientRepositoryProtocol {
    func fetchRecipients(
        url: URL,
        hash: String
    ) -> CompoundOperationWrapper<TransferAssetRecipientResponse> {
        let fetchOperation = ClosureOperation<KiltTransferAssetRecipientResponse> {
            guard let data = try? Data(contentsOf: url) else {
                throw KiltTransferAssetRecipientError.fileNotFound
            }

            guard let content = String(data: data, encoding: .utf8) else {
                throw KiltTransferAssetRecipientError.corruptedData
            }

            guard self.integrityVerifier.verify(
                serviceEndpointId: hash,
                serviceEndpointContent: content.trimmingCharacters(in: .whitespacesAndNewlines)
            ) else {
                throw KiltTransferAssetRecipientError.verificationFailed
            }

            do {
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .iso8601
                return try decoder.decode(KiltTransferAssetRecipientResponse.self, from: data)
            } catch {
                throw KiltTransferAssetRecipientError.decodingDataFailed(error)
            }
        }

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
