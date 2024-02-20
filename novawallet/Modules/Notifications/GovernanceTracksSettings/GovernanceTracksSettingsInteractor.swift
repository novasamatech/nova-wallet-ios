import UIKit

final class GovernanceTracksSettingsInteractor {
    weak var presenter: GovernanceTracksSettingsInteractorOutputProtocol?

    let fetchOperationFactory: ReferendumsOperationFactoryProtocol
    let runtimeProvider: RuntimeProviderProtocol
    let operationQueue: OperationQueue

    init(
        fetchOperationFactory: ReferendumsOperationFactoryProtocol,
        runtimeProvider: RuntimeProviderProtocol,
        operationQueue: OperationQueue
    ) {
        self.fetchOperationFactory = fetchOperationFactory
        self.runtimeProvider = runtimeProvider
        self.operationQueue = operationQueue
    }

    private func provideTracks() {
        let wrapper = fetchOperationFactory.fetchAllTracks(runtimeProvider: runtimeProvider)

        wrapper.targetOperation.completionBlock = { [weak self] in
            DispatchQueue.main.async {
                do {
                    let tracks = try wrapper.targetOperation.extractNoCancellableResultData()
                    self?.presenter?.didReceiveTracks(tracks)
                } catch {
                    self?.presenter?.didReceiveError(
                        GovernanceSelectTracksInteractorError.tracksFetchFailed(error)
                    )
                }
            }
        }

        operationQueue.addOperations(wrapper.allOperations, waitUntilFinished: false)
    }
}

extension GovernanceTracksSettingsInteractor: GovernanceTracksSettingsInteractorInputProtocol {
    func setup() {
        provideTracks()
    }

    func remakeSubscriptions() {}

    func retryTracksFetch() {
        provideTracks()
    }
}
