import Foundation
import Operation_iOS

extension ErrorPresentable where Self: AlertPresentable {
    func present(error: Error, from view: ControllerBackedProtocol?, locale: Locale?) -> Bool {
        guard let content = errorContent(from: error, locale: locale) else {
            return false
        }

        let closeAction = R.string.localizable.commonClose(preferredLanguages: locale?.rLanguages)

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

        let actionTitle = R.string.localizable.commonClose(preferredLanguages: locale?.rLanguages)
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
            let title = R.string.localizable.operationErrorTitle(preferredLanguages: locale?.rLanguages)
            let message = R.string.localizable.operationErrorMessage(preferredLanguages: locale?.rLanguages)

            return ErrorContent(title: title, message: message)
        }

        if (error as NSError).domain == NSURLErrorDomain {
            let title = R.string.localizable.connectionErrorTitle(preferredLanguages: locale?.rLanguages)
            let message = R.string.localizable.connectionErrorMessage_v2_2_0(preferredLanguages: locale?.rLanguages)

            return ErrorContent(title: title, message: message)
        }

        return nil
    }
}
