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
            R.string(preferredLanguages: locale.rLanguages).localizable.commonRetry()
        }

        return MessageSheetAction(title: title, handler: handler)
    }

    static func cancelAction(for handler: @escaping MessageSheetCallback) -> MessageSheetAction {
        let title = LocalizableResource { locale in
            R.string(preferredLanguages: locale.rLanguages).localizable.commonCancel()
        }

        return MessageSheetAction(title: title, handler: handler)
    }

    static func notNowAction(for handler: @escaping MessageSheetCallback) -> MessageSheetAction {
        let title = LocalizableResource { locale in
            R.string(preferredLanguages: locale.rLanguages).localizable.commonNotNow()
        }

        return MessageSheetAction(title: title, handler: handler)
    }

    static func okBackAction(for handler: @escaping MessageSheetCallback) -> MessageSheetAction {
        let title = LocalizableResource { locale in
            R.string(preferredLanguages: locale.rLanguages).localizable.commonOkBack()
        }

        return MessageSheetAction(title: title, handler: handler)
    }

    static func continueAction(for handler: @escaping MessageSheetCallback) -> MessageSheetAction {
        let title = LocalizableResource { locale in
            R.string(preferredLanguages: locale.rLanguages).localizable.commonContinue()
        }

        return MessageSheetAction(title: title, handler: handler)
    }
}
