import RobinHood

typealias Web3TransferRecipientResponse = [Caip19.AssetId: [Web3TransferRecipient]]

protocol Web3TransferRecipientRepositoryProtocol {
    func fetchRecipients(
        url: URL,
        hash: String?
    ) -> CompoundOperationWrapper<Web3TransferRecipientResponse>
}

final class KiltTransferAssetRecipientRepository: BaseFetchOperationFactory {
    typealias Response = [String: [Web3TransferRecipient]]

    let integrityVerifier: Web3NameIntegrityVerifierProtocol
    let timeout: TimeInterval?

    init(
        integrityVerifier: Web3NameIntegrityVerifierProtocol,
        timeout: TimeInterval? = 60
    ) {
        self.integrityVerifier = integrityVerifier
        self.timeout = timeout
    }

    private func createResultFactory<T>(hash: String?) -> AnyNetworkResultFactory<T> where T: Decodable {
        AnyNetworkResultFactory<T> { data in
            guard let content = String(data: data, encoding: .utf8) else {
                throw KiltTransferAssetRecipientError.corruptedData
            }

            if let hash = hash {
                let isValid = self.integrityVerifier.verify(
                    serviceEndpointId: hash,
                    serviceEndpointContent: content.trimmingCharacters(in: .whitespacesAndNewlines)
                )

                guard isValid else {
                    throw KiltTransferAssetRecipientError.verificationFailed
                }
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

extension KiltTransferAssetRecipientRepository: Web3TransferRecipientRepositoryProtocol {
    func fetchRecipients(
        url: URL,
        hash: String?
    ) -> CompoundOperationWrapper<Web3TransferRecipientResponse> {
        let requestFactory = createRequestFactory(from: url, shouldUseCache: false, timeout: timeout)
        let resultFactory: AnyNetworkResultFactory<Response> = createResultFactory(hash: hash)

        let networkOperation = NetworkOperation(requestFactory: requestFactory, resultFactory: resultFactory)

        let mapOperation = ClosureOperation {
            let fetchResult = try networkOperation.extractNoCancellableResultData()
            return fetchResult.reduce(into: Web3TransferRecipientResponse()) { result, next in
                if let assetId = try? Caip19.AssetId(raw: next.key) {
                    result[assetId] = next.value
                }
            }
        }

        mapOperation.addDependency(networkOperation)

        return CompoundOperationWrapper(targetOperation: mapOperation, dependencies: [networkOperation])
    }
}
