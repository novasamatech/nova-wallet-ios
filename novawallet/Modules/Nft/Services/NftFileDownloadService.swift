import Foundation
import RobinHood
import SubstrateSdk

struct NftMediaFetchResult {
    let localUrl: URL
    let type: String?
}

protocol NftFileDownloadServiceProtocol {
    func resolveImageUrl(
        for nftMetadata: String,
        dispatchQueue: DispatchQueue,
        completion: @escaping (Result<URL?, Error>) -> Void
    ) -> CancellableCall?

    func downloadMetadata(
        for nftMetadata: String,
        dispatchQueue: DispatchQueue,
        completion: @escaping (Result<JSON, Error>) -> Void
    ) -> CancellableCall?

    func imageUrl(from metadataReference: String) -> URL?
}

final class NftFileDownloadService {
    let cacheBasePath: String
    let fileRepository: FileRepositoryProtocol
    let fileDownloadFactory: FileDownloadOperationFactoryProtocol
    let operationQueue: OperationQueue

    init(
        cacheBasePath: String,
        fileRepository: FileRepositoryProtocol,
        fileDownloadFactory: FileDownloadOperationFactoryProtocol,
        operationQueue: OperationQueue
    ) {
        self.cacheBasePath = cacheBasePath
        self.fileRepository = fileRepository
        self.fileDownloadFactory = fileDownloadFactory
        self.operationQueue = operationQueue
    }

    func extractIPFSHash(from nftMetadata: String) -> String {
        let result = DistributedUrlParser().parse(url: nftMetadata)

        switch result {
        case let .ipfs(hash):
            return hash
        case .none:
            return nftMetadata
        }
    }

    private func createLocalJsonWrapper(for localPath: String) -> CompoundOperationWrapper<JSON?> {
        let localFetchOperation = fileRepository.readOperation(at: localPath)
        let decodingLocalOperation = ClosureOperation<JSON?> {
            if let data = try localFetchOperation.extractNoCancellableResultData() {
                return try JSONDecoder().decode(JSON.self, from: data)
            } else {
                return nil
            }
        }

        decodingLocalOperation.addDependency(localFetchOperation)

        return CompoundOperationWrapper(targetOperation: decodingLocalOperation, dependencies: [localFetchOperation])
    }

    private func createLoadMetadataWrapper(for ipfsHash: String) -> CompoundOperationWrapper<JSON> {
        let localFilePath = (cacheBasePath as NSString).appendingPathComponent(ipfsHash)

        let localCheckOperation = createLocalJsonWrapper(for: localFilePath)

        let localUrl = URL(fileURLWithPath: localFilePath)

        let remoteUrl = DistributedStorageOperationFactory.ipfsBaseUrl.appendingPathComponent(ipfsHash)

        let remoteDownloadOperation = fileDownloadFactory.createFileDownloadOperation(from: remoteUrl, to: localUrl)
        remoteDownloadOperation.addDependency(localCheckOperation.targetOperation)

        let localJsonWrapper = createLocalJsonWrapper(for: localFilePath)
        localJsonWrapper.addDependency(operations: [remoteDownloadOperation])

        remoteDownloadOperation.configurationBlock = {
            let json = try? localCheckOperation.targetOperation.extractNoCancellableResultData()

            if json != nil {
                remoteDownloadOperation.cancel()
                localJsonWrapper.cancel()
            }
        }

        let mapOperation = ClosureOperation<JSON> {
            if
                case let .success(optionalJson) = localCheckOperation.targetOperation.result,
                let json = optionalJson {
                return json
            }

            if case let .failure(error) = remoteDownloadOperation.result {
                throw error
            }

            if let localJson = try localJsonWrapper.targetOperation.extractNoCancellableResultData() {
                return localJson
            } else {
                throw BaseOperationError.unexpectedDependentResult
            }
        }

        mapOperation.addDependency(localJsonWrapper.targetOperation)

        let dependencies = localCheckOperation.allOperations + [remoteDownloadOperation] +
            localJsonWrapper.allOperations

        let wrapper = CompoundOperationWrapper(targetOperation: mapOperation, dependencies: dependencies)

        return wrapper
    }
}

extension NftFileDownloadService: NftFileDownloadServiceProtocol {
    func resolveImageUrl(
        for nftMetadata: String,
        dispatchQueue: DispatchQueue,
        completion: @escaping (Result<URL?, Error>) -> Void
    ) -> CancellableCall? {
        let ipfsHash = extractIPFSHash(from: nftMetadata)

        let fetchWrapper = createLoadMetadataWrapper(for: ipfsHash)

        let mapOperation = ClosureOperation<URL?> { [weak self] in
            let metadata = try fetchWrapper.targetOperation.extractNoCancellableResultData()

            if let image = metadata.image?.stringValue {
                return self?.imageUrl(from: image)
            } else {
                return nil
            }
        }

        mapOperation.addDependency(fetchWrapper.targetOperation)

        mapOperation.completionBlock = {
            do {
                let url = try mapOperation.extractNoCancellableResultData()
                dispatchQueue.async {
                    completion(.success(url))
                }
            } catch {
                dispatchQueue.async {
                    completion(.failure(error))
                }
            }
        }

        let wrapper = CompoundOperationWrapper(targetOperation: mapOperation, dependencies: fetchWrapper.allOperations)

        operationQueue.addOperations(wrapper.allOperations, waitUntilFinished: false)

        return wrapper
    }

    func downloadMetadata(
        for nftMetadata: String,
        dispatchQueue: DispatchQueue,
        completion: @escaping (Result<JSON, Error>) -> Void
    ) -> CancellableCall? {
        let ipfsHash = extractIPFSHash(from: nftMetadata)

        let wrapper = createLoadMetadataWrapper(for: ipfsHash)

        wrapper.targetOperation.completionBlock = {
            do {
                let model = try wrapper.targetOperation.extractNoCancellableResultData()
                dispatchQueue.async {
                    completion(.success(model))
                }
            } catch {
                dispatchQueue.async {
                    completion(.failure(error))
                }
            }
        }

        operationQueue.addOperations(wrapper.allOperations, waitUntilFinished: false)

        return wrapper
    }

    func imageUrl(from metadataReference: String) -> URL? {
        let parseResult = DistributedUrlParser().parse(url: metadataReference)

        switch parseResult {
        case let .ipfs(hash):
            return DistributedStorageOperationFactory.ipfsBaseUrl.appendingPathComponent(hash)
        case .none:
            return nil
        }
    }
}
