import UIKit
import Foundation
import Foundation_iOS

struct AccountAdditionalOption {
    let title: LocalizableResource<String>
    let icon: UIImage?
    let indicator: ChainAddressDetailsIndicator
    let onSelection: () -> Void
}

protocol AddressOptionsPresentable: ModalAlertPresenting, CopyAddressPresentable, UnifiedAddressPopupPresentable {
    func presentAccountOptions(
        from view: ControllerBackedProtocol,
        address: String,
        chain: ChainModel,
        locale: Locale
    )

    func presentExtendedAccountOptions(
        from view: ControllerBackedProtocol,
        address: String,
        chain: ChainModel,
        option: AccountAdditionalOption,
        locale: Locale
    )
}

extension AddressOptionsPresentable {
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
        let copyClosure = {
            copyAddressCheckingFormat(
                from: view,
                address: address,
                chain: chain,
                locale: locale
            )
        }

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

        view.controller.present(
            controller,
            animated: true,
            completion: nil
        )
    }

    func presentExtendedAccountOptions(
        from view: ControllerBackedProtocol,
        address: String,
        chain: ChainModel,
        option: AccountAdditionalOption,
        locale: Locale
    ) {
        let copyClosure = {
            copyAddressCheckingFormat(
                from: view,
                address: address,
                chain: chain,
                locale: locale
            )
        }

        let urlClosure = { (url: URL) in
            present(from: view, url: url)
        }

        guard let controller = AddressOptionsPresentableFactory.createAccountOptionsController(
            address: address,
            chain: chain,
            copyClosure: copyClosure,
            urlClosure: urlClosure,
            option: option
        ) else {
            return
        }

        view.controller.present(
            controller,
            animated: true,
            completion: nil
        )
    }
}

enum AddressOptionsPresentableFactory {
    static func createAccountOptionsController(
        address: String,
        chain: ChainModel,
        copyClosure: @escaping () -> Void,
        urlClosure: @escaping (URL) -> Void
    ) -> UIViewController? {
        let builder = createAccountOptionsBuilder(
            address: address,
            chain: chain,
            copyClosure: copyClosure,
            urlClosure: urlClosure
        )
        let model = builder.build()
        return ChainAddressDetailsPresentableFactory.createChainAddressDetails(
            for: model
        )?.controller
    }

    static func createAccountOptionsController(
        address: String,
        chain: ChainModel,
        copyClosure: @escaping () -> Void,
        urlClosure: @escaping (URL) -> Void,
        option: AccountAdditionalOption
    ) -> UIViewController? {
        let builder = createAccountOptionsBuilder(
            address: address,
            chain: chain,
            copyClosure: copyClosure,
            urlClosure: urlClosure
        ).addAction(
            for: option.title,
            icon: option.icon,
            indicator: option.indicator,
            onSelection: option.onSelection
        )
        let model = builder.build()
        return ChainAddressDetailsPresentableFactory.createChainAddressDetails(
            for: model
        )?.controller
    }

    static func createAccountOptionsBuilder(
        address: String,
        chain: ChainModel,
        copyClosure: @escaping () -> Void,
        urlClosure: @escaping (URL) -> Void
    ) -> ChainAddressDetailsModelBuilder {
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
                let url = try? URLBuilder(urlTemplate: accountTemplate)
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

        return builder
    }
}
