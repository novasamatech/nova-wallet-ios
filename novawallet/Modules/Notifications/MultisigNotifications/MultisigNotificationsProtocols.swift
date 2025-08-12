import Foundation

protocol MultisigNotificationsViewProtocol: ControllerBackedProtocol {
    func didReceive(viewModel: MultisigNotificationsViewModel)
}

protocol MultisigNotificationsPresenterProtocol: ChainNotificationSettingsPresenterProtocol {
    func proceed()
}

protocol MultisigNotificationsInteractorInputProtocol: AnyObject {
    func setup()
}

protocol MultisigNotificationsInteractorOutputProtocol: AnyObject {}

protocol MultisigNotificationsWireframeProtocol: AnyObject {
    func complete(settings: MultisigNotificationsModel)
}

struct MultisigNotificationsViewModel {
    let switchModels: [SwitchTitleIconViewModel]
}
