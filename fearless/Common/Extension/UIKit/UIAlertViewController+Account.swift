import UIKit
import RobinHood

extension UIAlertController {
    static func presentAccountOptions(
        _ address: String,
        chain: Chain,
        locale: Locale,
        copyClosure: @escaping () -> Void,
        urlClosure: @escaping (URL) -> Void
    ) -> UIAlertController {
        var title = address

        let offset = title.count / 2
        title.insert(
            contentsOf: String.returnKey,
            at: title.index(title.startIndex, offsetBy: offset)
        )

        let alertController = UIAlertController(
            title: title,
            message: nil,
            preferredStyle: .actionSheet
        )

        let copyTitle = R.string.localizable
            .commonCopyAddress(preferredLanguages: locale.rLanguages)

        let copy = UIAlertAction(title: copyTitle, style: .default) { _ in
            copyClosure()
        }

        alertController.addAction(copy)

        if let url = chain.polkascanAddressURL(address) {
            let polkascanTitle = R.string.localizable
                .transactionDetailsViewPolkascan(preferredLanguages: locale.rLanguages)
            let viewPolkascan = UIAlertAction(title: polkascanTitle, style: .default) { _ in
                urlClosure(url)
            }

            alertController.addAction(viewPolkascan)
        }

        if let url = chain.subscanAddressURL(address) {
            let subscanTitle = R.string.localizable
                .transactionDetailsViewSubscan(preferredLanguages: locale.rLanguages)
            let viewSubscan = UIAlertAction(title: subscanTitle, style: .default) { _ in
                urlClosure(url)
            }

            alertController.addAction(viewSubscan)
        }

        let cancelTitle = R.string.localizable
            .commonCancel(preferredLanguages: locale.rLanguages)
        let cancel = UIAlertAction(title: cancelTitle, style: .cancel, handler: nil)

        alertController.addAction(cancel)

        return alertController
    }

    static func presentAccountOptions(
        _ address: String,
        explorers: [ChainModel.Explorer]?,
        locale: Locale,
        copyClosure: @escaping () -> Void,
        urlClosure: @escaping (URL) -> Void
    ) -> UIAlertController {
        var title = address

        let offset = title.count / 2
        title.insert(
            contentsOf: String.returnKey,
            at: title.index(title.startIndex, offsetBy: offset)
        )

        let alertController = UIAlertController(
            title: title,
            message: nil,
            preferredStyle: .actionSheet
        )

        let copyTitle = R.string.localizable
            .commonCopyAddress(preferredLanguages: locale.rLanguages)

        let copy = UIAlertAction(title: copyTitle, style: .default) { _ in
            copyClosure()
        }

        alertController.addAction(copy)

        let actions: [UIAlertAction] = explorers?.compactMap { explorer in
            guard
                let accountTemplate = explorer.account,
                let url = try? EndpointBuilder(urlTemplate: accountTemplate)
                .buildParameterURL(address) else {
                return nil
            }

            return UIAlertAction(title: explorer.name, style: .default) { _ in
                urlClosure(url)
            }
        } ?? []

        actions.forEach { alertController.addAction($0) }

        let cancelTitle = R.string.localizable
            .commonCancel(preferredLanguages: locale.rLanguages)
        let cancel = UIAlertAction(title: cancelTitle, style: .cancel, handler: nil)

        alertController.addAction(cancel)

        return alertController
    }
}
