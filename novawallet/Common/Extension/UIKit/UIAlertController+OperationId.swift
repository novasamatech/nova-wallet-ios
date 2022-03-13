import UIKit
import SoraFoundation

private typealias NamedUrlTemplate = (name: String, template: String)

extension UIAlertController {
    static func presentTransactionHashOptions(
        _ transactionHash: String,
        explorers: [ChainModel.Explorer]?,
        locale: Locale,
        copyClosure: @escaping () -> Void,
        urlClosure: @escaping (URL) -> Void
    ) -> UIAlertController {
        let namedTemplates: [NamedUrlTemplate]? = explorers?.compactMap { explorer in
            if let urlTemplate = explorer.extrinsic {
                return NamedUrlTemplate(name: explorer.name, template: urlTemplate)
            } else {
                return nil
            }
        }

        var title = transactionHash

        let offset = title.count / 2
        title.insert(
            contentsOf: String.returnKey,
            at: title.index(title.startIndex, offsetBy: offset)
        )

        return presentOperationIdOptions(
            transactionHash,
            title: title,
            namedTemplates: namedTemplates,
            locale: locale,
            copyClosure: copyClosure,
            urlClosure: urlClosure
        )
    }

    static func presentEventIdOptions(
        _ eventId: String,
        explorers: [ChainModel.Explorer]?,
        locale: Locale,
        copyClosure: @escaping () -> Void,
        urlClosure: @escaping (URL) -> Void
    ) -> UIAlertController {
        let namedTemplates: [NamedUrlTemplate]? = explorers?.compactMap { explorer in
            if let urlTemplate = explorer.event {
                return NamedUrlTemplate(name: explorer.name, template: urlTemplate)
            } else {
                return nil
            }
        }

        return presentOperationIdOptions(
            eventId,
            title: eventId,
            namedTemplates: namedTemplates,
            locale: locale,
            copyClosure: copyClosure,
            urlClosure: urlClosure
        )
    }

    // swiftlint:disable:next function_parameter_count
    private static func presentOperationIdOptions(
        _ operationId: String,
        title: String,
        namedTemplates: [NamedUrlTemplate]?,
        locale: Locale,
        copyClosure: @escaping () -> Void,
        urlClosure: @escaping (URL) -> Void
    ) -> UIAlertController {
        let alertController = UIAlertController(
            title: title,
            message: nil,
            preferredStyle: .actionSheet
        )

        let copyTitle = R.string.localizable
            .commonCopyId(preferredLanguages: locale.rLanguages)

        let copy = UIAlertAction(title: copyTitle, style: .default) { _ in
            copyClosure()
        }

        alertController.addAction(copy)

        let actions: [UIAlertAction] = namedTemplates?.compactMap { namedTemplate in
            guard let url = try? EndpointBuilder(urlTemplate: namedTemplate.template)
                .buildParameterURL(operationId) else {
                return nil
            }

            let title = R.string.localizable.commmonViewInFormat(
                namedTemplate.name,
                preferredLanguages: locale.rLanguages
            )

            return UIAlertAction(title: title, style: .default) { _ in
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
