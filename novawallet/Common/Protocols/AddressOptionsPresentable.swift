import UIKit
import Foundation
import SoraFoundation
import RobinHood

protocol AddressOptionsPresentable {
    func presentAccountOptions(
        from view: ControllerBackedProtocol,
        address: String,
        chain: ChainModel,
        locale: Locale
    )
}

extension AddressOptionsPresentable {
    private func copyAddress(
        from view: ControllerBackedProtocol,
        address: String,
        locale: Locale
    ) {
        UIPasteboard.general.string = address

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

    func presentAccountOptions(
        from view: ControllerBackedProtocol,
        address: String,
        chain: ChainModel,
        locale: Locale
    ) {
        let copyClosure = { copyAddress(from: view, address: address, locale: locale) }

        let urlClosure = { (url: URL) in
            present(from: view, url: url)
        }

        guard let controller = AddressOptionsPresentableFactory.createAccountOptionsController(
            address: address,
            chain: chain,
            copyClosure: copyClosure,
            urlClosure: urlClosure
        ) else {
            return
        }

        view.controller.present(controller, animated: true, completion: nil)
    }
}

enum AddressOptionsPresentableFactory {
    static func createAccountOptionsController(
        address: String,
        chain: ChainModel,
        copyClosure: @escaping () -> Void,
        urlClosure: @escaping (URL) -> Void
    ) -> UIViewController? {
        let copyTitle = LocalizableResource { locale in
            R.string.localizable.commonCopyAddress(preferredLanguages: locale.rLanguages)
        }

        var builder = ChainAddressDetailsModelBuilder(
            address: address,
            chainName: chain.name,
            chainIcon: chain.icon
        ).addAction(
            for: copyTitle,
            icon: R.image.iconActionCopy(),
            indicator: .none,
            onSelection: copyClosure
        )

        (chain.explorers ?? []).forEach { explorer in
            guard
                let accountTemplate = explorer.account,
                let url = try? RobinHood.EndpointBuilder(urlTemplate: accountTemplate)
                .buildParameterURL(address) else {
                return
            }

            let title = LocalizableResource { locale in
                R.string.localizable.commmonViewInFormat(
                    explorer.name,
                    preferredLanguages: locale.rLanguages
                )
            }

            builder = builder.addAction(
                for: title,
                icon: R.image.iconActionWeb(),
                indicator: .navigation,
                onSelection: { urlClosure(url) }
            )
        }

        let model = builder.build()

        return ChainAddressDetailsPresentableFactory.createChainAddressDetails(
            for: model
        )?.controller
    }
}
