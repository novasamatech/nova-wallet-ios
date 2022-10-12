import UIKit
import SubstrateSdk
import RobinHood

final class ReferendumDetailsInteractor: AnyCancellableCleaning {
    weak var presenter: ReferendumDetailsInteractorOutputProtocol?

    private(set) var referendum: ReferendumLocal
    let chain: ChainModel
    let actionDetailsOperationFactory: ReferendumActionOperationFactoryProtocol
    let connection: JSONRPCEngine
    let runtimeProvider: RuntimeProviderProtocol
    let identityOperationFactory: IdentityOperationFactoryProtocol
    let blockTimeService: BlockTimeEstimationServiceProtocol
    let priceLocalSubscriptionFactory: PriceProviderFactoryProtocol
    let generalLocalSubscriptionFactory: GeneralStorageSubscriptionFactoryProtocol
    let govMetadataLocalSubscriptionFactory: GovMetadataLocalSubscriptionFactoryProtocol
    let referendumsOperationFactory: ReferendumsOperationFactoryProtocol
    let operationQueue: OperationQueue

    private var priceProvider: AnySingleValueProvider<PriceData>?
    private var blockNumberSubscription: AnyDataProvider<DecodedBlockNumber>?
    private var referendumSubscription: CallbackStorageSubscription<ReferendumInfo>?
    private var referendumCancellable: CancellableCall?
    private var identitiesCancellable: CancellableCall?
    private var actionDetailsCancellable: CancellableCall?

    init(
        referendum: ReferendumLocal,
        chain: ChainModel,
        actionDetailsOperationFactory: ReferendumActionOperationFactoryProtocol,
        connection: JSONRPCEngine,
        runtimeProvider: RuntimeProviderProtocol,
        blockTimeService: BlockTimeEstimationServiceProtocol,
        identityOperationFactory: IdentityOperationFactoryProtocol,
        priceLocalSubscriptionFactory: PriceProviderFactoryProtocol,
        generalLocalSubscriptionFactory: GeneralStorageSubscriptionFactoryProtocol,
        govMetadataLocalSubscriptionFactory: GovMetadataLocalSubscriptionFactoryProtocol,
        referendumsOperationFactory: ReferendumsOperationFactoryProtocol,
        currencyManager: CurrencyManagerProtocol,
        operationQueue: OperationQueue
    ) {
        self.referendum = referendum
        self.chain = chain
        self.actionDetailsOperationFactory = actionDetailsOperationFactory
        self.connection = connection
        self.runtimeProvider = runtimeProvider
        self.identityOperationFactory = identityOperationFactory
        self.priceLocalSubscriptionFactory = priceLocalSubscriptionFactory
        self.generalLocalSubscriptionFactory = generalLocalSubscriptionFactory
        self.blockTimeService = blockTimeService
        self.govMetadataLocalSubscriptionFactory = govMetadataLocalSubscriptionFactory
        self.referendumsOperationFactory = referendumsOperationFactory
        self.operationQueue = operationQueue
        self.currencyManager = currencyManager
    }

    deinit {
        clear(cancellable: &referendumCancellable)
        clear(cancellable: &identitiesCancellable)
        clear(cancellable: &actionDetailsCancellable)

        referendumSubscription = nil
    }

    private func provideReferendum(for referendumInfo: ReferendumInfo) {
        clear(cancellable: &referendumCancellable)

        let wrapper = referendumsOperationFactory.fetchReferendumWrapper(
            for: referendumInfo,
            index: Referenda.ReferendumIndex(referendum.index),
            connection: connection,
            runtimeProvider: runtimeProvider
        )

        wrapper.targetOperation.completionBlock = { [weak self] in
            DispatchQueue.main.async {
                guard wrapper === self?.referendumCancellable else {
                    return
                }

                self?.referendumCancellable = nil

                do {
                    let referendum = try wrapper.targetOperation.extractNoCancellableResultData()
                    self?.referendum = referendum

                    self?.presenter?.didReceiveReferendum(referendum)
                } catch {
                    self?.presenter?.didReceiveError(.referendumFailed(error))
                }
            }
        }

        referendumCancellable = wrapper

        operationQueue.addOperations(wrapper.allOperations, waitUntilFinished: false)
    }

    private func handleReferendumSubscription(result: Result<ReferendumInfo?, Error>) {
        switch result {
        case let .success(referendumInfo):
            if let referendumInfo = referendumInfo {
                provideReferendum(for: referendumInfo)
            }
        case let .failure(error):
            presenter?.didReceiveError(.referendumFailed(error))
        }
    }

    private func subscribeReferendum() {
        let referendumIndex = referendum.index

        let request = MapSubscriptionRequest(
            storagePath: Referenda.referendumInfo,
            localKey: ""
        ) {
            StringScaleMapper(value: referendumIndex)
        }

        referendumSubscription = CallbackStorageSubscription<ReferendumInfo>(
            request: request,
            connection: connection,
            runtimeService: runtimeProvider,
            repository: nil,
            operationQueue: operationQueue,
            callbackQueue: .main
        ) { [weak self] result in
            self?.handleReferendumSubscription(result: result)
        }
    }

    private func provideIdentities() {
        guard let proposer = referendum.proposer else {
            presenter?.didReceiveIdentities([:])
            return
        }

        guard identitiesCancellable == nil else {
            return
        }

        let accountIds: () throws -> [AccountId] = {
            [proposer]
        }

        let wrapper = identityOperationFactory.createIdentityWrapper(
            for: accountIds,
            engine: connection,
            runtimeService: runtimeProvider,
            chainFormat: chain.chainFormat
        )

        wrapper.targetOperation.completionBlock = { [weak self] in
            DispatchQueue.main.async {
                guard wrapper === self?.identitiesCancellable else {
                    return
                }

                self?.identitiesCancellable = nil

                do {
                    let identities = try wrapper.targetOperation.extractNoCancellableResultData()
                    self?.presenter?.didReceiveIdentities(identities)
                } catch {
                    self?.presenter?.didReceiveError(.identitiesFailed(error))
                }
            }
        }

        identitiesCancellable = wrapper

        operationQueue.addOperations(wrapper.allOperations, waitUntilFinished: false)
    }

    private func provideActionDetails() {
        guard actionDetailsCancellable == nil else {
            return
        }

        let wrapper = actionDetailsOperationFactory.fetchActionWrapper(
            for: referendum,
            connection: connection,
            runtimeProvider: runtimeProvider
        )

        wrapper.targetOperation.completionBlock = { [weak self] in
            DispatchQueue.main.async {
                guard wrapper === self?.actionDetailsCancellable else {
                    return
                }

                self?.actionDetailsCancellable = nil

                do {
                    let actionDetails = try wrapper.targetOperation.extractNoCancellableResultData()
                    self?.presenter?.didReceiveActionDetails(actionDetails)
                } catch {
                    self?.presenter?.didReceiveError(.actionDetailsFailed(error))
                }
            }
        }
    }

    private func makeSubscriptions() {
        if let priceId = chain.utilityAsset()?.priceId {
            priceProvider = subscribeToPrice(for: priceId, currency: selectedCurrency)
        }

        blockNumberSubscription = subscribeToBlockNumber(for: chain.chainId)

        subscribeReferendum()
    }
}

extension ReferendumDetailsInteractor: ReferendumDetailsInteractorInputProtocol {
    func setup() {
        presenter?.didReceiveReferendum(referendum)

        makeSubscriptions()
        provideActionDetails()
        provideIdentities()
    }
}

extension ReferendumDetailsInteractor: GeneralLocalStorageSubscriber, GeneralLocalStorageHandler {
    func handleBlockNumber(result: Result<BlockNumber?, Error>, chainId: ChainModel.Id) {
        switch result {
        case let .success(blockNumber):
            if let blockNumber = blockNumber {
                presenter?.didReceiveBlockNumber(blockNumber)
            }
        case let .failure(error):
            presenter?.didReceiveError(.blockNumberFailed(error))
        }
    }
}

extension ReferendumDetailsInteractor: PriceLocalSubscriptionHandler, PriceLocalStorageSubscriber {
    func handlePrice(result: Result<PriceData?, Error>, priceId _: AssetModel.PriceId) {
        switch result {
        case let .success(price):
            presenter?.didReceivePrice(price)
        case let .failure(error):
            presenter?.didReceiveError(.priceFailed(error))
        }
    }
}

extension ReferendumDetailsInteractor: SelectedCurrencyDepending {
    func applyCurrency() {
        if presenter != nil {
            if let priceId = chain.utilityAsset()?.priceId {
                priceProvider = subscribeToPrice(for: priceId, currency: selectedCurrency)
            }
        }
    }
}
