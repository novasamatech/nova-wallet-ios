import UIKit

final class GovernanceTracksSettingsInteractor {
    weak var presenter: SelectTracksInteractorOutputProtocol?

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
                    self?.presenter?.didReceiveError(selectTracksError: .tracksFetchFailed(error))
                }
            }
        }

        operationQueue.addOperations(wrapper.allOperations, waitUntilFinished: false)
    }
}

extension GovernanceTracksSettingsInteractor: SelectTracksInteractorInputProtocol {
    func setup() {
        provideTracks()
    }

    func retryTracksFetch() {
        provideTracks()
    }
}
