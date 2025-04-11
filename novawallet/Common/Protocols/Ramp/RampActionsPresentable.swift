import Foundation
import Foundation_iOS

private typealias ModalActionsContext = (
    actions: [LocalizableResource<ActionManageViewModel>],
    context: ModalPickerClosureContext
)

private enum ManageActions: Int {
    case buy = 0
    case sell
}

struct RampActionAvailabilityOptions: OptionSet {
    typealias RawValue = UInt8

    static let onRamp = RampActionAvailabilityOptions(rawValue: 1 << 0)
    static let offRamp = RampActionAvailabilityOptions(rawValue: 1 << 1)
    static let all: RampActionAvailabilityOptions = [.onRamp, .offRamp]
    static let none: RampActionAvailabilityOptions = []

    let rawValue: UInt8

    var notEmpty: Bool {
        self != Self.none
    }

    init(rawValue: RawValue) {
        self.rawValue = rawValue
    }

    init(from rampType: RampActionType) {
        switch rampType {
        case .onRamp: self = .onRamp
        case .offRamp: self = .offRamp
        }
    }
}

protocol RampActionsPresentable: ActionsManagePresentable {
    func presentRampActionsSheet(
        from view: ControllerBackedProtocol?,
        availableOptions: RampActionAvailabilityOptions,
        delegate: ModalPickerViewControllerDelegate?,
        locale: Locale,
        onActionSelect: @escaping (RampActionType) -> Void
    )
}

extension RampActionsPresentable where Self: AlertPresentable {
    func presentRampActionsSheet(
        from view: ControllerBackedProtocol?,
        availableOptions: RampActionAvailabilityOptions,
        delegate: ModalPickerViewControllerDelegate?,
        locale: Locale,
        onActionSelect: @escaping (RampActionType) -> Void
    ) {
        guard let view else { return }

        guard availableOptions.notEmpty else {
            showRampNotSupported(
                availableOptions: availableOptions,
                from: view,
                locale: locale
            )

            return
        }

        let modalActionsContext = createModalActionsContext(
            availableOptions: availableOptions,
            onActionAvailable: onActionSelect,
            onActionUnavailable: { [weak self] in
                self?.showRampNotSupported(
                    availableOptions: availableOptions,
                    from: view,
                    locale: locale
                )
            }
        )

        presentActionsManage(
            from: view,
            actions: modalActionsContext.actions,
            title: nil,
            delegate: delegate,
            context: modalActionsContext.context
        )
    }
}

private extension RampActionsPresentable where Self: AlertPresentable {
    func createModalActionsContext(
        availableOptions: RampActionAvailabilityOptions,
        onActionAvailable: @escaping (RampActionType) -> Void,
        onActionUnavailable: @escaping () -> Void
    ) -> ModalActionsContext {
        var actionViewModels: [LocalizableResource<ActionManageViewModel>] = [
            LocalizableResource { locale in
                ActionManageViewModel(
                    icon: R.image.iconAddStroke(),
                    title: R.string.localizable.tokenActionsPickerBuy(preferredLanguages: locale.rLanguages),
                    style: availableOptions.contains(.onRamp) ? .available : .unavailable
                )
            },
            LocalizableResource { locale in
                ActionManageViewModel(
                    icon: R.image.iconSellStroke(),
                    title: R.string.localizable.tokenActionsPickerSell(preferredLanguages: locale.rLanguages),
                    style: availableOptions.contains(.offRamp) ? .available : .unavailable
                )
            }
        ]

        let context = ModalPickerClosureContext { index in
            guard let manageAction = ManageActions(rawValue: index) else {
                return
            }

            let actionType: RampActionType = switch manageAction {
            case .buy: .onRamp
            case .sell: .offRamp
            }

            if availableOptions.contains(.init(from: actionType)) {
                onActionAvailable(actionType)
            } else {
                onActionUnavailable()
            }
        }

        return (actionViewModels, context)
    }

    func showRampNotSupported(
        availableOptions: RampActionAvailabilityOptions,
        from view: ControllerBackedProtocol?,
        locale: Locale
    ) {
        let languages = locale.rLanguages
        let localizable = R.string.localizable.self

        let (title, message): (String, String)

        if !availableOptions.notEmpty {
            title = localizable.rampNotSupportedAlertTitle(preferredLanguages: languages)
            message = localizable.rampNotSupportedAlertMessage(preferredLanguages: languages)
        } else if !availableOptions.contains(.onRamp) {
            title = localizable.onRampNotSupportedAlertTitle(preferredLanguages: languages)
            message = localizable.onRampNotSupportedAlertMessage(preferredLanguages: languages)
        } else if !availableOptions.contains(.offRamp) {
            title = localizable.offRampNotSupportedAlertTitle(preferredLanguages: languages)
            message = localizable.offRampNotSupportedAlertMessage(preferredLanguages: languages)
        } else {
            return
        }

        let actionTitle = localizable.commonGotIt(preferredLanguages: languages)

        present(
            message: message,
            title: title,
            closeAction: actionTitle,
            from: view
        )
    }
}
