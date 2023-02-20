import Foundation

typealias WalletNoAccountHandlingWireframe = AlertPresentable & NoAccountSupportPresentable

struct WalletNoAccountHandlingParams {
    let wallet: MetaAccountModel
    let chain: ChainModel
    let accountManagementFilter: AccountManagementFilterProtocol
    let successHandler: () -> Void
    let newAccountHandler: () -> Void
}

protocol WalletNoAccountHandling {
    func validateAccount(
        from params: WalletNoAccountHandlingParams,
        view: ControllerBackedProtocol,
        wireframe: WalletNoAccountHandlingWireframe,
        locale: Locale
    )
}

extension WalletNoAccountHandling {
    func validateAccount(
        from params: WalletNoAccountHandlingParams,
        view: ControllerBackedProtocol,
        wireframe: WalletNoAccountHandlingWireframe,
        locale: Locale
    ) {
        let wallet = params.wallet
        let chain = params.chain
        let accountManagementFilter = params.accountManagementFilter

        if wallet.fetch(for: chain.accountRequest()) != nil {
            params.successHandler()
        } else if accountManagementFilter.canAddAccount(to: wallet, chain: chain) {
            let message = R.string.localizable.commonChainCrowdloanAccountMissingMessage(
                chain.name,
                preferredLanguages: locale.rLanguages
            )

            wireframe.presentAddAccount(
                from: view,
                chainName: chain.name,
                message: message,
                locale: locale,
                addClosure: params.newAccountHandler
            )
        } else {
            wireframe.presentNoAccountSupport(
                from: view,
                walletType: wallet.type,
                chainName: chain.name,
                locale: locale
            )
        }
    }
}
