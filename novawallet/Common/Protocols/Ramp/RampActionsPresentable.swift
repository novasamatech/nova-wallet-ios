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

enum RampActionAvailability {
    case available(RampActionType)
    case unavailable(RampActionType)

    var type: RampActionType {
        switch self {
        case let .available(rampType), let .unavailable(rampType):
            return rampType
        }
    }

    var available: Bool {
        switch self {
        case .available: true
        case .unavailable: false
        }
    }

    func available(_ type: RampActionType) -> Bool {
        switch self {
        case let .available(rampType): rampType == type
        case .unavailable: false
        }
    }
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

extension Array where Element == RampActionAvailability {
    var options: RampActionAvailabilityOptions {
        reduce(into: .init(rawValue: 0)) { result, availability in
            switch availability.type {
            case .onRamp where availability.available:
                result.insert(.onRamp)
            case .offRamp where availability.available:
                result.insert(.offRamp)
            default:
                break
            }
        }
    }
}

protocol RampActionsPresentable: ActionsManagePresentable {
    func presentRampActionsSheet(
        from view: ControllerBackedProtocol?,
        availableTypes: [RampActionAvailability],
        delegate: ModalPickerViewControllerDelegate?,
        locale: Locale,
        onActionSelect: @escaping (RampActionType) -> Void
    )
}

extension RampActionsPresentable where Self: AlertPresentable {
    func presentRampActionsSheet(
        from view: ControllerBackedProtocol?,
        availableTypes: [RampActionAvailability],
        delegate: ModalPickerViewControllerDelegate?,
        locale: Locale,
        onActionSelect: @escaping (RampActionType) -> Void
    ) {
        guard let view else { return }

        guard availableTypes.options.notEmpty else {
            showRampNotSupported(
                availableTypes: availableTypes,
                from: view,
                locale: locale
            )

            return
        }

        let modalActionsContext = createModalActionsContext(
            availableTypes: availableTypes,
            onActionAvailable: onActionSelect,
            onActionUnavailable: { [weak self] in
                self?.showRampNotSupported(
                    availableTypes: availableTypes,
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
        availableTypes: [RampActionAvailability],
        onActionAvailable: @escaping (RampActionType) -> Void,
        onActionUnavailable: @escaping () -> Void
    ) -> ModalActionsContext {
        let actionViewModels: [LocalizableResource<ActionManageViewModel>] = availableTypes.map { rampAvailability in
            let style: ActionManageStyle = rampAvailability.available == true
                ? .available
                : .unavailable

            return switch rampAvailability.type {
            case .onRamp:
                LocalizableResource { locale in
                    ActionManageViewModel(
                        icon: R.image.iconAddStroke(),
                        title: R.string.localizable.tokenActionsPickerBuy(preferredLanguages: locale.rLanguages),
                        style: style
                    )
                }
            case .offRamp:
                LocalizableResource { locale in
                    ActionManageViewModel(
                        icon: R.image.iconSellStroke(),
                        title: R.string.localizable.tokenActionsPickerSell(preferredLanguages: locale.rLanguages),
                        style: style
                    )
                }
            }
        }

        let context = ModalPickerClosureContext { index in
            guard let manageAction = ManageActions(rawValue: index) else {
                return
            }

            let actionType: RampActionType = switch manageAction {
            case .buy: .onRamp
            case .sell: .offRamp
            }

            if availableTypes.options.contains(.init(from: actionType)) {
                onActionAvailable(actionType)
            } else {
                onActionUnavailable()
            }
        }

        return (actionViewModels, context)
    }

    func showRampNotSupported(
        availableTypes: [RampActionAvailability],
        from view: ControllerBackedProtocol?,
        locale: Locale
    ) {
        let languages = locale.rLanguages
        let localizable = R.string.localizable.self

        let (title, message): (String, String)

        if !availableTypes.options.notEmpty {
            title = localizable.rampNotSupportedAlertTitle(preferredLanguages: languages)
            message = localizable.rampNotSupportedAlertMessage(preferredLanguages: languages)
        } else if !availableTypes.options.contains(.onRamp) {
            title = localizable.onRampNotSupportedAlertTitle(preferredLanguages: languages)
            message = localizable.onRampNotSupportedAlertMessage(preferredLanguages: languages)
        } else if !availableTypes.options.contains(.offRamp) {
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
