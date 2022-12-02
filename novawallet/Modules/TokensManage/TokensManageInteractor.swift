import UIKit

final class TokensManageInteractor {
    weak var presenter: TokensManageInteractorOutputProtocol!
}

extension TokensManageInteractor: TokensManageInteractorInputProtocol {}
