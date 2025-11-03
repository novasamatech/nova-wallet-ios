import UIKit
import Operation_iOS

final class GiftPrepareShareInteractor {
    weak var presenter: GiftPrepareShareInteractorOutputProtocol?

    let giftId: GiftModel.Id
    let giftRepository: AnyDataProviderRepository<GiftModel>
    let operationQueue: OperationQueue

    let logger: LoggerProtocol

    init(
        giftRepository: AnyDataProviderRepository<GiftModel>,
        giftId: GiftModel.Id,
        operationQueue: OperationQueue,
        logger: LoggerProtocol
    ) {
        self.giftRepository = giftRepository
        self.giftId = giftId
        self.operationQueue = operationQueue
        self.logger = logger
    }
}

// MARK: - Private

private extension GiftPrepareShareInteractor {
    func provideGift(for giftId: GiftModel.Id) {
        let fetchOperation = giftRepository.fetchOperation(
            by: { giftId },
            options: .init()
        )

        execute(
            operation: fetchOperation,
            inOperationQueue: operationQueue,
            runningCallbackIn: .main
        ) { [weak self] result in
            switch result {
            case let .success(gift):
                guard let gift else { return }

                self?.presenter?.didReceive(gift)
            case let .failure(error):
                self?.logger.error("Failed on fetch local gift: \(error)")
            }
        }
    }
}

extension GiftPrepareShareInteractor: GiftPrepareShareInteractorInputProtocol {
    func setup() {
        provideGift(for: giftId)
    }
}
