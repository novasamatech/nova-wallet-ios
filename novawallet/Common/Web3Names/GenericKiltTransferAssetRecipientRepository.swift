import Foundation
import RobinHood

class GenericKiltTransferAssetRecipientRepository<Response: Decodable>:
    BaseFetchOperationFactory, Web3TransferRecipientRepositoryProtocol {
    let integrityVerifier: Web3NameIntegrityVerifierProtocol
    let timeout: TimeInterval?
    let mapper: (Response) -> Web3TransferRecipientResponse

    init(
        integrityVerifier: Web3NameIntegrityVerifierProtocol,
        timeout: TimeInterval? = 60,
        mapper: @escaping (Response) -> Web3TransferRecipientResponse
    ) {
        self.integrityVerifier = integrityVerifier
        self.timeout = timeout
        self.mapper = mapper
    }

    private func createResultFactory<T>(hash: String?) -> AnyNetworkResultFactory<T> where T: Decodable {
        AnyNetworkResultFactory<T> { data in
            guard let content = String(data: data, encoding: .utf8) else {
                throw KiltTransferAssetRecipientError.corruptedData
            }

            if let hash = hash {
                let isValid = self.integrityVerifier.verify(
                    serviceEndpointId: hash,
                    serviceEndpointContent: content
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

    func fetchRecipients(
        url: URL,
        hash: String?
    ) -> CompoundOperationWrapper<Web3TransferRecipientResponse> {
        let requestFactory = createRequestFactory(from: url, shouldUseCache: false, timeout: timeout)
        let resultFactory: AnyNetworkResultFactory<Response> = createResultFactory(hash: hash)

        let networkOperation = NetworkOperation(requestFactory: requestFactory, resultFactory: resultFactory)

        let mapOperation = ClosureOperation {
            let fetchResult = try networkOperation.extractNoCancellableResultData()
            return self.mapper(fetchResult)
        }

        mapOperation.addDependency(networkOperation)

        return CompoundOperationWrapper(targetOperation: mapOperation, dependencies: [networkOperation])
    }
}
