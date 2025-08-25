import Foundation
import Foundation_iOS
import UIKit

struct MessageSheetAction {
    enum ActionType {
        case normal
        case destructive
    }

    let title: LocalizableResource<String>
    let handler: MessageSheetCallback
    let actionType: ActionType

    init(
        title: LocalizableResource<String>,
        handler: @escaping MessageSheetCallback,
        actionType: ActionType = .normal
    ) {
        self.title = title
        self.handler = handler
        self.actionType = actionType
    }
}

enum MessageSheetText {
    case raw(String)
    case attributed(NSAttributedString)
}

struct MessageSheetViewModel<IType, CType> {
    let title: LocalizableResource<String>
    let message: LocalizableResource<MessageSheetText>
    let graphics: IType?
    let content: CType?
    let mainAction: MessageSheetAction?
    let secondaryAction: MessageSheetAction?

    init(
        title: LocalizableResource<String>,
        message: LocalizableResource<MessageSheetText>,
        graphics: IType?,
        content: CType?,
        mainAction: MessageSheetAction?,
        secondaryAction: MessageSheetAction?
    ) {
        self.title = title
        self.message = message
        self.graphics = graphics
        self.content = content
        self.mainAction = mainAction
        self.secondaryAction = secondaryAction
    }

    init(
        title: LocalizableResource<String>,
        message: LocalizableResource<String>,
        graphics: IType?,
        content: CType?,
        mainAction: MessageSheetAction?,
        secondaryAction: MessageSheetAction?
    ) {
        self.title = title
        self.message = LocalizableResource { locale in
            let string = message.value(for: locale)
            return .raw(string)
        }
        self.graphics = graphics
        self.content = content
        self.mainAction = mainAction
        self.secondaryAction = secondaryAction
    }

    init(
        title: LocalizableResource<String>,
        message: LocalizableResource<NSAttributedString>,
        graphics: IType?,
        content: CType?,
        mainAction: MessageSheetAction?,
        secondaryAction: MessageSheetAction?
    ) {
        self.title = title
        self.message = LocalizableResource { locale in
            let attributedText = message.value(for: locale)
            return .attributed(attributedText)
        }
        self.graphics = graphics
        self.content = content
        self.mainAction = mainAction
        self.secondaryAction = secondaryAction
    }
}

extension MessageSheetAction {
    static func retryAction(for handler: @escaping MessageSheetCallback) -> MessageSheetAction {
        let title = LocalizableResource { locale in
            R.string.localizable.commonRetry(preferredLanguages: locale.rLanguages)
        }

        return MessageSheetAction(title: title, handler: handler)
    }

    static func cancelAction(for handler: @escaping MessageSheetCallback) -> MessageSheetAction {
        let title = LocalizableResource { locale in
            R.string.localizable.commonCancel(preferredLanguages: locale.rLanguages)
        }

        return MessageSheetAction(title: title, handler: handler)
    }

    static func notNowAction(for handler: @escaping MessageSheetCallback) -> MessageSheetAction {
        let title = LocalizableResource { locale in
            R.string.localizable.commonNotNow(preferredLanguages: locale.rLanguages)
        }

        return MessageSheetAction(title: title, handler: handler)
    }

    static func okBackAction(for handler: @escaping MessageSheetCallback) -> MessageSheetAction {
        let title = LocalizableResource { locale in
            R.string.localizable.commonOkBack(preferredLanguages: locale.rLanguages)
        }

        return MessageSheetAction(title: title, handler: handler)
    }

    static func continueAction(for handler: @escaping MessageSheetCallback) -> MessageSheetAction {
        let title = LocalizableResource { locale in
            R.string.localizable.commonContinue(preferredLanguages: locale.rLanguages)
        }

        return MessageSheetAction(title: title, handler: handler)
    }
}
