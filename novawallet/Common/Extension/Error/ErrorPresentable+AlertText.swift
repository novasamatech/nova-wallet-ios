import Foundation
import Operation_iOS

extension ErrorPresentable where Self: AlertPresentable {
    func present(error: Error, from view: ControllerBackedProtocol?, locale: Locale?) -> Bool {
        guard let content = errorContent(from: error, locale: locale) else {
            return false
        }

        let closeAction = R.string(preferredLanguages: locale.rLanguages).localizable.commonClose()

        present(message: content.message, title: content.title, closeAction: closeAction, from: view)

        return true
    }

    @discardableResult
    func present(
        error: Error,
        from view: ControllerBackedProtocol?,
        locale: Locale?,
        completion: @escaping () -> Void
    ) -> Bool {
        guard let content = errorContent(from: error, locale: locale) else {
            return false
        }

        let actionTitle = R.string(preferredLanguages: locale.rLanguages).localizable.commonClose()
        let closeAction = AlertPresentableAction(title: actionTitle, style: .cancel, handler: completion)

        let viewModel = AlertPresentableViewModel(
            title: content.title,
            message: content.message,
            actions: [closeAction],
            closeAction: nil
        )
        present(
            viewModel: viewModel,
            style: .alert,
            from: view
        )

        return true
    }

    private func errorContent(from error: Error, locale: Locale?) -> ErrorContent? {
        if let contentConvertibleError = error as? ErrorContentConvertible {
            return contentConvertibleError.toErrorContent(for: locale)
        }

        if error as? BaseOperationError != nil {
            let title = R.string(preferredLanguages: locale.rLanguages).localizable.operationErrorTitle()
            let message = R.string(preferredLanguages: locale.rLanguages).localizable.operationErrorMessage()

            return ErrorContent(title: title, message: message)
        }

        if (error as NSError).domain == NSURLErrorDomain {
            let title = R.string(preferredLanguages: locale.rLanguages).localizable.connectionErrorTitle()
            let message = R.string(preferredLanguages: locale.rLanguages).localizable.connectionErrorMessage_v2_2_0()

            return ErrorContent(title: title, message: message)
        }

        return nil
    }
}
