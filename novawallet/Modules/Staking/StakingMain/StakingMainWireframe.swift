import Foundation

final class StakingMainWireframe: StakingMainWireframeProtocol {
    func showAccountsSelection(from view: StakingMainViewProtocol?) {
        guard let accountManagement = WalletSelectionViewFactory.createView() else {
            return
        }

        let navigationController = FearlessNavigationController(
            rootViewController: accountManagement.controller
        )

        view?.controller.present(navigationController, animated: true, completion: nil)
    }

    func showChainAssetSelection(
        from view: StakingMainViewProtocol?,
        selectedChainAssetId: ChainAssetId?,
        delegate: AssetSelectionDelegate
    ) {
        let stakingFilter: AssetSelectionFilter = { chainAsset in
            StakingType(rawType: chainAsset.asset.staking) != .unsupported
        }

        guard let selectionView = AssetSelectionViewFactory.createView(
            delegate: delegate,
            selectedChainAssetId: selectedChainAssetId,
            assetFilter: stakingFilter
        ) else {
            return
        }

        let navigationController = FearlessNavigationController(
            rootViewController: selectionView.controller
        )

        view?.controller.present(navigationController, animated: true, completion: nil)
    }

    func showCreateAccount(
        from view: ControllerBackedProtocol?,
        wallet: MetaAccountModel,
        chain: ChainModel
    ) {
        guard let createAccountView = AccountCreateViewFactory.createViewForReplaceChainAccount(
            metaAccountModel: wallet,
            chainModelId: chain.chainId,
            isEthereumBased: chain.isEthereumBased
        ) else {
            return
        }

        let controller = createAccountView.controller
        controller.hidesBottomBarWhenPushed = true
        if let navigationController = view?.controller.navigationController {
            navigationController.pushViewController(controller, animated: true)
        }
    }

    func showImportAccount(
        from view: ControllerBackedProtocol?,
        wallet: MetaAccountModel,
        chain: ChainModel
    ) {
        let options = SecretSource.displayOptions

        let handler: (Int) -> Void = { [weak self] selectedIndex in
            self?.presentImport(
                from: view,
                secretSource: options[selectedIndex],
                wallet: wallet,
                chainId: chain.chainId,
                isEthereumBased: chain.isEthereumBased
            )
        }

        guard let picker = ModalPickerFactory.createPickerListForSecretSource(
            options: options,
            delegate: self,
            context: ModalPickerClosureContext(handler: handler)
        ) else {
            return
        }

        view?.controller.present(picker, animated: true, completion: nil)
    }

    private func presentImport(
        from view: ControllerBackedProtocol?,
        secretSource: SecretSource,
        wallet: MetaAccountModel,
        chainId: ChainModel.Id,
        isEthereumBased: Bool
    ) {
        guard let importAccountView = AccountImportViewFactory.createViewForReplaceChainAccount(
            secretSource: secretSource,
            modelId: chainId,
            isEthereumBased: isEthereumBased,
            in: wallet
        ) else {
            return
        }

        let controller = importAccountView.controller
        controller.hidesBottomBarWhenPushed = true
        if let navigationController = view?.controller.navigationController {
            navigationController.pushViewController(controller, animated: true)
        }
    }
}

extension StakingMainWireframe: ModalPickerViewControllerDelegate {
    func modalPickerDidSelectModelAtIndex(_ index: Int, context: AnyObject?) {
        guard let closureContext = context as? ModalPickerClosureContext else {
            return
        }

        closureContext.process(selectedIndex: index)
    }
}
