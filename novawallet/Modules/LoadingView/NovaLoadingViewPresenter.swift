import Foundation
import UIKit_iOS

final class NovaLoadingViewPresenter: LoadingViewPresenter {
    static let shared = NovaLoadingViewPresenter(factory: NovaLoadingViewFactory.self)

    override private init(factory: LoadingViewFactoryProtocol.Type) {
        super.init(factory: factory)
    }
}
