import Foundation
import SoraFoundation
import UIKit

struct MessageSheetAction {
    let title: LocalizableResource<String>
    let handler: MessageSheetCallback
}

struct MessageSheetViewModel<IType, CType> {
    let title: LocalizableResource<String>
    let message: LocalizableResource<String>
    let graphics: IType?
    let content: CType?
    let mainAction: MessageSheetAction?
    let secondaryAction: MessageSheetAction?
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

    static func okBackAction(for handler: @escaping MessageSheetCallback) -> MessageSheetAction {
        let title = LocalizableResource { locale in
            R.string.localizable.commonOkBack(preferredLanguages: locale.rLanguages)
        }

        return MessageSheetAction(title: title, handler: handler)
    }
}
