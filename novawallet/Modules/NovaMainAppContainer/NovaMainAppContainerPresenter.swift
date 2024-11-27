import Foundation

final class NovaMainAppContainerPresenter {
    weak var view: NovaMainAppContainerViewProtocol?
    let wireframe: NovaMainAppContainerWireframeProtocol

    init(wireframe: NovaMainAppContainerWireframeProtocol) {
        self.wireframe = wireframe
    }
}

// MARK: NovaMainAppContainerPresenterProtocol

extension NovaMainAppContainerPresenter: NovaMainAppContainerPresenterProtocol {
    func openBrowser(tabsCount: Int) {
        if tabsCount > 1 {
            wireframe.showBrowserTabs(from: view)
        } else {
            // Implement
        }
    }
}
