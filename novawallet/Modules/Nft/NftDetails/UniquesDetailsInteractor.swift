import Foundation
import RobinHood
import SubstrateSdk

final class UniquesDetailsInteractor: NftDetailsInteractor {
    let operationFactory: UniquesOperationFactoryProtocol
    let chainRegistry: ChainRegistryProtocol

    private(set) var classDetailsOperation: CancellableCall?
    private(set) var classMetadataOperation: CancellableCall?

    init(
        nftChainModel: NftChainModel,
        accountRepository: AnyDataProviderRepository<MetaAccountModel>,
        operationFactory: UniquesOperationFactoryProtocol,
        nftMetadataService: NftFileDownloadServiceProtocol,
        chainRegistry: ChainRegistryProtocol,
        operationQueue: OperationQueue
    ) {
        self.operationFactory = operationFactory
        self.chainRegistry = chainRegistry

        super.init(
            nftChainModel: nftChainModel,
            accountRepository: accountRepository,
            nftMetadataService: nftMetadataService,
            operationQueue: operationQueue
        )
    }

    deinit {
        classDetailsOperation?.cancel()
        classMetadataOperation?.cancel()
    }

    private func provideCollectionInfo(from json: JSON) {
        let name = json.name?.stringValue

        let imageUrl: URL?

        if let imageReference = json.image?.stringValue {
            imageUrl = nftMetadataService.imageUrl(from: imageReference)
        } else {
            imageUrl = nil
        }

        let collectionName = name ?? nftChainModel.nft.collectionId ?? ""
        let collection = NftDetailsCollection(name: collectionName, imageUrl: imageUrl)

        presenter?.didReceive(collection: collection)
    }

    private func provideCollectionInfo(for dataReference: Data) {
        guard classMetadataOperation == nil else {
            return
        }

        if let metadataReference = String(data: dataReference, encoding: .utf8) {
            classMetadataOperation = nftMetadataService.downloadMetadata(
                for: metadataReference,
                dispatchQueue: .main
            ) { [weak self] result in
                self?.classMetadataOperation = nil

                switch result {
                case let .success(json):
                    self?.provideCollectionInfo(from: json)
                case let .failure(error):
                    self?.presenter?.didReceive(error: error)
                }
            }
        } else {
            let error = NftDetailsInteractorError.unsupportedMetadata(dataReference)
            presenter?.didReceive(error: error)
        }
    }

    private func provideIssuer(for issuerId: AccountId) {
        guard classDetailsOperation == nil else {
            return
        }

        classDetailsOperation = fetchDisplayAddress(for: issuerId, chain: chain) { [weak self] result in
            self?.classDetailsOperation = nil

            DispatchQueue.main.async {
                switch result {
                case let .success(address):
                    self?.presenter?.didReceive(issuer: address)
                case let .failure(error):
                    self?.presenter?.didReceive(error: error)
                }
            }
        }
    }

    private func provideClassDetails() {
        guard classDetailsOperation == nil else {
            return
        }

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

            let allWrapper = CompoundOperationWrapper(
                targetOperation: classDetailsWrapper.targetOperation,
                dependencies: [codingFactoryOperation] + classDetailsWrapper.dependencies
            )

            classDetailsOperation = allWrapper

            classDetailsWrapper.targetOperation.completionBlock = { [weak self] in
                DispatchQueue.main.async {
                    self?.classDetailsOperation = nil

                    do {
                        let metadata = try classDetailsWrapper.targetOperation.extractNoCancellableResultData()

                        if let issuer = metadata[classId]?.issuer {
                            self?.provideIssuer(for: issuer)
                        } else {
                            self?.presenter?.didReceive(issuer: nil)
                        }
                    } catch {
                        self?.presenter?.didReceive(error: error)
                    }
                }
            }

            operationQueue.addOperations(allWrapper.allOperations, waitUntilFinished: false)

        } else {
            presenter?.didReceive(issuer: nil)
        }
    }

    private func provideClassMetadata() {
        guard classMetadataOperation == nil else {
            return
        }

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

            let allWrapper = CompoundOperationWrapper(
                targetOperation: classMetadataWrapper.targetOperation,
                dependencies: [codingFactoryOperation] + classMetadataWrapper.dependencies
            )

            classMetadataOperation = allWrapper

            classMetadataWrapper.targetOperation.completionBlock = { [weak self] in
                DispatchQueue.main.async {
                    self?.classMetadataOperation = nil

                    do {
                        let metadata = try classMetadataWrapper.targetOperation.extractNoCancellableResultData()

                        if let data = metadata[classId]?.data {
                            self?.provideCollectionInfo(for: data)
                        } else {
                            self?.presenter?.didReceive(collection: nil)
                        }
                    } catch {
                        self?.presenter?.didReceive(error: error)
                    }
                }
            }

            let operations = [codingFactoryOperation] + classMetadataWrapper.allOperations

            operationQueue.addOperations(operations, waitUntilFinished: false)

        } else {
            presenter?.didReceive(collection: nil)
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

            presenter?.didReceive(label: label)
        } else {
            presenter?.didReceive(label: .unlimited)
        }
    }

    private func load() {
        provideInstanceMetadata()
        provideLabel()
        provideOwner()
        provideClassMetadata()
        provideClassDetails()
        providePrice()
    }
}

extension UniquesDetailsInteractor: NftDetailsInteractorInputProtocol {
    func setup() {
        load()
    }

    func refresh() {
        load()
    }
}
