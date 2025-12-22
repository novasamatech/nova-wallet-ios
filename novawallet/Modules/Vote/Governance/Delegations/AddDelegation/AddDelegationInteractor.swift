import Foundation
import SubstrateSdk
import Operation_iOS
import Keystore_iOS

final class AddDelegationInteractor {
    weak var presenter: AddDelegationInteractorOutputProtocol?

    let chain: ChainModel
    let lastVotedDays: Int
    let delegateListOperationFactory: GovernanceDelegateListFactoryProtocol
    let timepointThresholdService: TimepointThresholdServiceProtocol
    private(set) var settings: SettingsManagerProtocol
    let govJsonProviderFactory: JsonDataProviderFactoryProtocol
    let operationQueue: OperationQueue

    private var metadataProvider: AnySingleValueProvider<[GovernanceDelegateMetadataRemote]>?
    private var blockNumberSubscription: AnyDataProvider<DecodedBlockNumber>?
    private var currentThreshold: TimepointThreshold?

    init(
        chain: ChainModel,
        lastVotedDays: Int,
        timepointThresholdService: TimepointThresholdServiceProtocol,
        delegateListOperationFactory: GovernanceDelegateListFactoryProtocol,
        govJsonProviderFactory: JsonDataProviderFactoryProtocol,
        settings: SettingsManagerProtocol,
        operationQueue: OperationQueue
    ) {
        self.chain = chain
        self.lastVotedDays = lastVotedDays
        self.timepointThresholdService = timepointThresholdService
        self.delegateListOperationFactory = delegateListOperationFactory
        self.govJsonProviderFactory = govJsonProviderFactory
        self.settings = settings
        self.operationQueue = operationQueue
    }

    private func fetchDelegates() {
        guard let currentThreshold else {
            return
        }

        let thresholdIndays = currentThreshold.backIn(seconds: TimeInterval(lastVotedDays).secondsFromDays)

        let wrapper = delegateListOperationFactory.fetchDelegateListWrapper(for: thresholdIndays)

        execute(
            wrapper: wrapper,
            inOperationQueue: operationQueue,
            runningCallbackIn: .main
        ) { [weak self] result in
            switch result {
            case let .success(delegates):
                self?.presenter?.didReceiveDelegates(delegates)
            case let .failure(error):
                self?.presenter?.didReceiveError(.delegateListFetchFailed(error))
            }
        }
    }

    private func subscribeTimepointThreshold() {
        timepointThresholdService.remove(observer: self)

        timepointThresholdService.add(
            observer: self,
            sendStateOnSubscription: true,
            queue: .main
        ) { [weak self] _, timepointThreshold in
            guard let self, let timepointThreshold else { return }
            let previousThreshold = currentThreshold
            currentThreshold = timepointThreshold

            if
                case let .block(newBlockNumber, _) = timepointThreshold.type,
                case let .block(previousBlockNumber, _) = previousThreshold?.type,
                newBlockNumber.isNext(to: previousBlockNumber) {
                return
            }

            fetchDelegates()
        }
    }

    private func provideSettings() {
        presenter?.didReceiveShouldDisplayBanner(settings.governanceDelegateInfoSeen)
    }

    private func subscribeToDelegatesMetadata() {
        metadataProvider?.removeObserver(self)
        metadataProvider = subscribeDelegatesMetadata(for: chain)
    }
}

extension AddDelegationInteractor: AddDelegationInteractorInputProtocol {
    func setup() {
        timepointThresholdService.setup()
        subscribeTimepointThreshold()
        subscribeToDelegatesMetadata()
        provideSettings()
    }

    func remakeSubscriptions() {
        subscribeTimepointThreshold()
        subscribeToDelegatesMetadata()
    }

    func refreshDelegates() {
        fetchDelegates()
    }

    func saveCloseBanner() {
        settings.governanceDelegateInfoSeen = true
    }
}

extension AddDelegationInteractor: GovJsonLocalStorageSubscriber, GovJsonLocalStorageHandler {
    func handleDelegatesMetadata(result: Result<[GovernanceDelegateMetadataRemote], Error>, chain _: ChainModel) {
        switch result {
        case let .success(metadata):
            presenter?.didReceiveMetadata(metadata)
        case let .failure(error):
            presenter?.didReceiveError(.metadataSubscriptionFailed(error))
        }
    }
}
