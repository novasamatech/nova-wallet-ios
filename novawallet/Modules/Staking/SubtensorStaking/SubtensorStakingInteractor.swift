import Foundation
import BigInt

final class SubtensorStakingInteractor: SubtensorStakingInteractorInputProtocol {
    weak var presenter: SubtensorStakingInteractorOutputProtocol?

    private let service: SubtensorStakingService
    private var setupTask: Task<Void, Never>?

    init(service: SubtensorStakingService) {
        self.service = service
    }

    deinit {
        setupTask?.cancel()
    }

    func setup() {
        setupTask?.cancel()
        setupTask = Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                let positions = try await service.fetchUserStakePositions()
                guard !Task.isCancelled else { return }
                presenter?.didReceive(positions: positions)
            } catch {
                guard !Task.isCancelled else { return }
                presenter?.didReceive(error: error)
            }
        }
    }

    func refresh() {
        setup()
    }
}
