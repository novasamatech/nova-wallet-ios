import Foundation

final class InAppUpdatesPresenter {
    weak var view: InAppUpdatesViewProtocol?
    let wireframe: InAppUpdatesWireframeProtocol
    let interactor: InAppUpdatesInteractorInputProtocol

    init(
        interactor: InAppUpdatesInteractorInputProtocol,
        wireframe: InAppUpdatesWireframeProtocol
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
    }
}

extension InAppUpdatesPresenter: InAppUpdatesPresenterProtocol {
    func setup() {
        interactor.setup()
    }
}

extension InAppUpdatesPresenter: InAppUpdatesInteractorOutputProtocol {
    func didReceive(error _: InAppUpdatesInteractorError) {
        print("Error")
    }

    func didReceiveLastVersion(changelog _: ChangeLog) {
        print("didReceiveLastVersion")
    }

    func didReceiveAllVersions(changelogs _: [ChangeLog]) {
        print("didReceiveAllVersions")
    }
}
