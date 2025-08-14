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

protocol MultisigNotificationsInteractorOutputProtocol: AnyObject {
    func didReceive(multisigWallets: [MetaAccountModel])
}

protocol MultisigNotificationsWireframeProtocol: AnyObject, AlertPresentable, WebPresentable {
    func complete(settings: MultisigNotificationsModel)

    func showLearnMore(from view: ControllerBackedProtocol?)
}

struct MultisigNotificationsViewModel {
    let switchModels: [SwitchTitleIconViewModel]

    var enabled: Bool {
        switchModels.contains(where: { $0.isOn })
    }
}
