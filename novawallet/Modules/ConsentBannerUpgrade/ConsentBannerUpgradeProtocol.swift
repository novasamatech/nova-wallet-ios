import Foundation
import Foundation_iOS

protocol ConsentBannerUpgradeViewProtocol: ControllerBackedProtocol {}

protocol ConsentBannerUpgradePresenterProtocol: AnyObject {
    func setup()
    func acceptConsent()
    func activateTerms()
    func activatePrivacy()
}

protocol ConsentBannerUpgradeWireframeProtocol: AnyObject {
    func close(view: ConsentBannerUpgradeViewProtocol?, completion: (() -> Void)?)
}

protocol ConsentBannerUpgradeViewFactoryProtocol {
    static func createView(completion: @escaping () -> Void) -> ConsentBannerUpgradeViewProtocol?
}
