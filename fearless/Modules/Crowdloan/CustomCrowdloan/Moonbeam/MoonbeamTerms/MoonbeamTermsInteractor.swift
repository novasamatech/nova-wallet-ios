import UIKit

final class MoonbeamTermsInteractor {
    weak var presenter: MoonbeamTermsInteractorOutputProtocol!
}

extension MoonbeamTermsInteractor: MoonbeamTermsInteractorInputProtocol {}
