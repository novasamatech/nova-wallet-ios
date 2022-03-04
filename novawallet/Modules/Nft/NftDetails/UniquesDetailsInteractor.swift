import Foundation
import RobinHood
import SubstrateSdk

final class UniquesDetailsInteractor: NftDetailsInteractor {
    let operationFactory: UniquesOperationFactoryProtocol
    let metadataService: NftFileDownloadServiceProtocol
    let chainRegistry: ChainRegistryProtocol

    init(
        nftChainModel: NftChainModel,
        accountRepository: AnyDataProviderRepository<MetaAccountModel>,
        operationFactory: UniquesOperationFactoryProtocol,
        metadataService: NftFileDownloadServiceProtocol,
        chainRegistry: ChainRegistryProtocol,
        operationQueue: OperationQueue
    ) {
        self.operationFactory = operationFactory
        self.metadataService = metadataService
        self.chainRegistry = chainRegistry

        super.init(
            nftChainModel: nftChainModel,
            accountRepository: accountRepository,
            operationQueue: operationQueue
        )
    }

    private func provideInstanceInfo(from json: JSON) {
        let name = json.name?.stringValue
        presenter.didReceiveName(result: .success(name))

        let description = json.description?.stringValue
        presenter.didReceiveDescription(result: .success(description))

        if let imageReference = json.image?.stringValue {
            let mediaViewModel = NftMediaViewModel(metadataReference: imageReference, downloadService: metadataService)
            presenter.didReceiveMedia(result: .success(mediaViewModel))
        } else {
            presenter.didReceiveMedia(result: .success(nil))
        }
    }

    private func provideInstanceMetadata() {
        if let metadata = nftChainModel.nft.metadata {
            guard let metadataReference = String(data: metadata, encoding: .utf8) else {
                let error = NftDetailsInteractorError.unsupportedMetadata(metadata)
                presenter.didReceiveName(result: .failure(error))
                presenter.didReceiveMedia(result: .failure(error))
                presenter.didReceiveDescription(result: .failure(error))
                return
            }

            metadataService.downloadMetadata(
                for: metadataReference,
                dispatchQueue: .main
            ) { [weak self] result in
                switch result {
                case let .success(json):
                    self?.provideInstanceInfo(from: json)
                case let .failure(error):
                    self?.presenter.didReceiveName(result: .failure(error))
                    self?.presenter.didReceiveMedia(result: .failure(error))
                    self?.presenter.didReceiveDescription(result: .failure(error))
                }
            }

        } else {
            presenter.didReceiveName(result: .success(nil))
            presenter.didReceiveMedia(result: .success(nil))
            presenter.didReceiveDescription(result: .success(nil))
        }
    }

    private func provideCollectionInfo(from json: JSON) {
        let name = json.name?.stringValue

        let imageUrl: URL?

        if let imageReference = json.image?.stringValue {
            imageUrl = metadataService.imageUrl(from: imageReference)
        } else {
            imageUrl = nil
        }

        let collectionName = name ?? nftChainModel.nft.collectionId ?? ""
        let collection = NftDetailsCollection(name: collectionName, imageUrl: imageUrl)

        presenter.didReceiveCollection(result: .success(collection))
    }

    private func provideCollectionInfo(for dataReference: Data) {
        if let metadataReference = String(data: dataReference, encoding: .utf8) {
            _ = metadataService.downloadMetadata(
                for: metadataReference,
                dispatchQueue: .main
            ) { [weak self] result in
                switch result {
                case let .success(json):
                    self?.provideCollectionInfo(from: json)
                case let .failure(error):
                    self?.presenter.didReceiveCollection(
                        result: .failure(error)
                    )
                }
            }
        } else {
            presenter.didReceiveCollection(
                result: .failure(NftDetailsInteractorError.unsupportedMetadata(dataReference))
            )
        }
    }

    private func provideIssuer(for issuerId: AccountId) {
        fetchDisplayAddress(for: issuerId, chain: chain) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case let .success(address):
                    self?.presenter.didReceiveIssuer(result: .success(address))
                case let .failure(error):
                    self?.presenter.didReceiveIssuer(result: .failure(error))
                }
            }
        }
    }

    private func provideClassDetails() {
        if
            let collectionId = nftChainModel.nft.collectionId,
            let classId = UInt32(collectionId),
            let connection = chainRegistry.getConnection(for: chain.chainId),
            let runtimeProvider = chainRegistry.getRuntimeProvider(for: chain.chainId) {
            let codingFactoryOperation = runtimeProvider.fetchCoderFactoryOperation()

            let classDetailsWrapper = operationFactory.createClassDetails(
                for: { [classId] },
                connection: connection,
                operationManager: OperationManager(operationQueue: operationQueue),
                codingFactoryClosure: {
                    try codingFactoryOperation.extractNoCancellableResultData()
                }
            )

            classDetailsWrapper.addDependency(operations: [codingFactoryOperation])

            classDetailsWrapper.targetOperation.completionBlock = { [weak self] in
                DispatchQueue.main.async {
                    do {
                        let metadata = try classDetailsWrapper.targetOperation.extractNoCancellableResultData()

                        if let issuer = metadata[classId]?.issuer {
                            self?.provideIssuer(for: issuer)
                        } else {
                            self?.presenter.didReceiveIssuer(result: .success(nil))
                        }
                    } catch {
                        self?.presenter.didReceiveIssuer(result: .failure(error))
                    }
                }
            }

            let operations = [codingFactoryOperation] + classDetailsWrapper.allOperations

            operationQueue.addOperations(operations, waitUntilFinished: false)

        } else {
            presenter.didReceiveIssuer(result: .success(nil))
        }
    }

    private func provideClassMetadata() {
        if
            let collectionId = nftChainModel.nft.collectionId,
            let classId = UInt32(collectionId),
            let connection = chainRegistry.getConnection(for: chain.chainId),
            let runtimeProvider = chainRegistry.getRuntimeProvider(for: chain.chainId) {
            let codingFactoryOperation = runtimeProvider.fetchCoderFactoryOperation()

            let classMetadataWrapper = operationFactory.createClassMetadataWrapper(
                for: { [classId] },
                connection: connection,
                operationManager: OperationManager(operationQueue: operationQueue),
                codingFactoryClosure: {
                    try codingFactoryOperation.extractNoCancellableResultData()
                }
            )

            classMetadataWrapper.addDependency(operations: [codingFactoryOperation])

            classMetadataWrapper.targetOperation.completionBlock = { [weak self] in
                DispatchQueue.main.async {
                    do {
                        let metadata = try classMetadataWrapper.targetOperation.extractNoCancellableResultData()

                        if let data = metadata[classId]?.data {
                            self?.provideCollectionInfo(for: data)
                        } else {
                            self?.presenter.didReceiveCollection(result: .success(nil))
                        }
                    } catch {
                        self?.presenter.didReceiveCollection(result: .failure(error))
                    }
                }
            }

            let operations = [codingFactoryOperation] + classMetadataWrapper.allOperations

            operationQueue.addOperations(operations, waitUntilFinished: false)

        } else {
            presenter.didReceiveCollection(result: .success(nil))
        }
    }

    private func provideLabel() {
        if
            let instanceIdString = nftChainModel.nft.instanceId,
            let instanceId = UInt32(instanceIdString),
            let totalIssuance = nftChainModel.nft.totalIssuance {
            let label: NftDetailsLabel = .limited(
                serialNumber: instanceId,
                totalIssuance: UInt32(bitPattern: totalIssuance)
            )

            presenter.didReceiveLabel(result: .success(label))
        } else {
            presenter.didReceiveLabel(result: .success(.unlimited))
        }
    }
}

extension UniquesDetailsInteractor: NftDetailsInteractorInputProtocol {
    func setup() {
        provideChainAsset()
        provideInstanceMetadata()
        provideLabel()
        provideOwner()
        provideClassMetadata()
        providePrice()
    }
}
