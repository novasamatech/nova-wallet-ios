import Foundation

final class WalletConnectPresenter {
    weak var interactor: WalletConnectInteractorInputProtocol?

    let logger: LoggerProtocol

    init(logger: LoggerProtocol) {
        self.logger = logger
    }
}

extension WalletConnectPresenter: WalletConnectInteractorOutputProtocol {}
