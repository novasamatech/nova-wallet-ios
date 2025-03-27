import Foundation
import SoraFoundation

private typealias ModalActionsContext = (
    actions: [LocalizableResource<ActionManageViewModel>],
    context: ModalPickerClosureContext
)

private enum ManageActions: Int {
    case buy = 0
    case sell
}

protocol RampActionsPresentable: ActionsManagePresentable {
    func presentRampActionsSheet(
        from view: ControllerBackedProtocol?,
        delegate: ModalPickerViewControllerDelegate?,
        onActionSelect: @escaping (RampActionType) -> Void
    )
}

extension RampActionsPresentable {
    func presentRampActionsSheet(
        from view: ControllerBackedProtocol?,
        delegate: ModalPickerViewControllerDelegate?,
        onActionSelect: @escaping (RampActionType) -> Void
    ) {
        guard let view else { return }

        let modalActionsContext = createModalActionsContext(onActionSelect: onActionSelect)

        presentActionsManage(
            from: view,
            actions: modalActionsContext.actions,
            title: nil,
            delegate: delegate,
            context: modalActionsContext.context
        )
    }

    private func createModalActionsContext(onActionSelect: @escaping (RampActionType) -> Void) -> ModalActionsContext {
        let actionViewModels: [LocalizableResource<ActionManageViewModel>] = [
            LocalizableResource { locale in
                ActionManageViewModel(
                    icon: R.image.iconAddStroke(),
                    title: R.string.localizable.tokenActionsPickerBuy(preferredLanguages: locale.rLanguages)
                )
            },
            LocalizableResource { locale in
                ActionManageViewModel(
                    icon: R.image.iconSellStroke(),
                    title: R.string.localizable.tokenActionsPickerSell(preferredLanguages: locale.rLanguages)
                )
            }
        ]

        let context = ModalPickerClosureContext { index in
            guard let manageAction = ManageActions(rawValue: index) else {
                return
            }

            switch manageAction {
            case .buy: onActionSelect(.onRamp)
            case .sell: onActionSelect(.offRamp)
            }
        }

        return (actionViewModels, context)
    }
}
