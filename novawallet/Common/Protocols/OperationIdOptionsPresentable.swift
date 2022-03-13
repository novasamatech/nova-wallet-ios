import UIKit

protocol OperationIdOptionsPresentable {
    func presentTransactionHashOptions(
        from view: ControllerBackedProtocol,
        transactionHash: String,
        explorers: [ChainModel.Explorer]?,
        locale: Locale
    )

    func presentEventIdOptions(
        from view: ControllerBackedProtocol,
        eventId: String,
        explorers: [ChainModel.Explorer]?,
        locale: Locale
    )
}

extension OperationIdOptionsPresentable {
    private func copyId(
        from view: ControllerBackedProtocol,
        operationId: String,
        locale: Locale
    ) {
        UIPasteboard.general.string = operationId

        let title = R.string.localizable.commonCopied(preferredLanguages: locale.rLanguages)
        let controller = ModalAlertFactory.createSuccessAlert(title)

        view.controller.present(
            controller,
            animated: true,
            completion: nil
        )
    }

    private func present(
        from view: ControllerBackedProtocol,
        url: URL
    ) {
        let webController = WebViewFactory.createWebViewController(for: url, style: .automatic)
        view.controller.present(
            webController,
            animated: true,
            completion: nil
        )
    }

    func presentTransactionHashOptions(
        from view: ControllerBackedProtocol,
        transactionHash: String,
        explorers: [ChainModel.Explorer]?,
        locale: Locale
    ) {
        let copyClosure = { copyId(from: view, operationId: transactionHash, locale: locale) }

        let urlClosure = { (url: URL) in
            present(from: view, url: url)
        }

        let controller = UIAlertController.presentTransactionHashOptions(
            transactionHash,
            explorers: explorers,
            locale: locale,
            copyClosure: copyClosure,
            urlClosure: urlClosure
        )

        view.controller.present(controller, animated: true, completion: nil)
    }

    func presentEventIdOptions(
        from view: ControllerBackedProtocol,
        eventId: String,
        explorers: [ChainModel.Explorer]?,
        locale: Locale
    ) {
        let copyClosure = { copyId(from: view, operationId: eventId, locale: locale) }

        let urlClosure = { (url: URL) in
            present(from: view, url: url)
        }

        let controller = UIAlertController.presentEventIdOptions(
            eventId,
            explorers: explorers,
            locale: locale,
            copyClosure: copyClosure,
            urlClosure: urlClosure
        )

        view.controller.present(controller, animated: true, completion: nil)
    }
}
