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

protocol BuySellActionsPresentable: ActionsManagePresentable {
    func presentBuySellSheet(
        from view: ControllerBackedProtocol?,
        delegate: ModalPickerViewControllerDelegate?,
        buyAction: @escaping () -> Void,
        sellAction: @escaping () -> Void
    )
}

extension BuySellActionsPresentable {
    func presentBuySellSheet(
        from view: ControllerBackedProtocol?,
        delegate: ModalPickerViewControllerDelegate?,
        buyAction: @escaping () -> Void,
        sellAction: @escaping () -> Void
    ) {
        guard let view else { return }

        let modalActionsContext = createModalActionsContext(
            buyAction: buyAction,
            sellAction: sellAction
        )
        presentActionsManage(
            from: view,
            actions: modalActionsContext.actions,
            title: nil,
            delegate: delegate,
            context: modalActionsContext.context
        )
    }

    private func createModalActionsContext(
        buyAction: @escaping () -> Void,
        sellAction: @escaping () -> Void
    ) -> ModalActionsContext {
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
            case .buy:
                buyAction()
            case .sell:
                sellAction()
            }
        }

        return (actionViewModels, context)
    }
}
