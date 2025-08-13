import Foundation

protocol MultisigNotificationsViewProtocol: ControllerBackedProtocol {
    func didReceive(viewModel: MultisigNotificationsViewModel)
}

protocol MultisigNotificationsPresenterProtocol: BaseNotificationSettingsPresenterProtocol {
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

    var enabled: Bool {
        switchModels.contains(where: { $0.isOn })
    }
}
