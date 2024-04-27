import UIKit

final class WalletImportOptionsInteractor {
    weak var presenter: WalletImportOptionsInteractorOutputProtocol?
}

extension WalletImportOptionsInteractor: WalletImportOptionsInteractorInputProtocol {}
