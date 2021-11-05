import RobinHood
import SoraFoundation

final class MoonbeamFlowCoordinator: Coordinator {
    let service: MoonbeamBonusServiceProtocol
    let paraId: ParaId
    let metaAccount: MetaAccountModel
    let operationManager: OperationManagerProtocol
    let previousView: (ControllerBackedProtocol & AlertPresentable & LoadableViewProtocol)?
    let state: CrowdloanSharedState
    let localizationManager: LocalizationManagerProtocol
    let crowdloanDisplayName: String
    let accountManagementWireframe: AccountManagementWireframeProtocol
    let crowdloanChainId: String

    init(
        state: CrowdloanSharedState,
        paraId: ParaId,
        metaAccount: MetaAccountModel,
        service: MoonbeamBonusServiceProtocol,
        operationManager: OperationManagerProtocol,
        previousView: (ControllerBackedProtocol & AlertPresentable & LoadableViewProtocol)?,
        accountManagementWireframe: AccountManagementWireframeProtocol,
        crowdloanDisplayName: String,
        crowdloanChainId: String,
        localizationManager: LocalizationManagerProtocol
    ) {
        self.state = state
        self.paraId = paraId
        self.metaAccount = metaAccount
        self.service = service
        self.operationManager = operationManager
        self.previousView = previousView
        self.accountManagementWireframe = accountManagementWireframe
        self.crowdloanDisplayName = crowdloanDisplayName
        self.crowdloanChainId = crowdloanChainId
        self.localizationManager = localizationManager
    }

    func start() {
        if service.hasMoonbeamAccount {
            checkHealth()
        } else {
            showMoonbeamAccountAlert()
        }
    }

    func checkHealth() {
        let healthOperation = service.createCheckHealthOperation()
        previousView?.didStartLoading()

        healthOperation.completionBlock = { [weak self] in
            DispatchQueue.main.async {
                self?.previousView?.didStopLoading()
                do {
                    _ = try healthOperation.extractNoCancellableResultData()
                    self?.checkAgreement()
                } catch {
                    let locale = self?.localizationManager.selectedLocale ?? .current
                    self?.previousView?.present(
                        message: R.string.localizable
                            .crowdloanMoonbeamRegionRestrictionMessage(preferredLanguages: locale.rLanguages),
                        title: R.string.localizable
                            .crowdloanMoonbeamRegionRestrictionTitle(preferredLanguages: locale.rLanguages),
                        closeAction: R.string.localizable.commonOk(preferredLanguages: locale.rLanguages),
                        from: nil
                    )
                }
            }
        }

        operationManager.enqueue(operations: [healthOperation], in: .transient)
    }

    func showMoonbeamAccountAlert() {
        let locale = localizationManager.selectedLocale

        let viewModel = AlertPresentableViewModel(
            title: R.string.localizable
                .crowdloanMoonbeamMissingAccountTitle(preferredLanguages: locale.rLanguages),
            message: R.string.localizable
                .crowdloanMoonbeamMissingAccountMessage(preferredLanguages: locale.rLanguages),
            actions: [
                .init(
                    title: R.string.localizable.commonCancel(preferredLanguages: locale.rLanguages),
                    style: .destructive
                ),
                .init(
                    title: R.string.localizable.commonAdd(preferredLanguages: locale.rLanguages),
                    style: .normal,
                    handler: { [weak self] in
                        self?.showAccountActions()
                    }
                )
            ],
            closeAction: nil
        )
        previousView?.present(viewModel: viewModel, style: .alert, from: previousView)
    }

    private func showAccountActions() {
        guard let chain = state.settings.value else { return }

        let createAccountAction = createAccountCreateAction(for: chain)
        let importAccountAction = createAccountImportAction(for: chain)

        let actions: [AlertPresentableAction] = [createAccountAction, importAccountAction]

        let locale = localizationManager.selectedLocale
        let closeTitle = R.string.localizable
            .commonCancel(preferredLanguages: locale.rLanguages)

        let actionsViewModel = AlertPresentableViewModel(
            title: crowdloanDisplayName,
            message: nil,
            actions: actions,
            closeAction: closeTitle
        )

        previousView?.present(
            viewModel: actionsViewModel,
            style: .actionSheet,
            from: previousView
        )
    }

    private func createAccountCreateAction(for chain: ChainModel) -> AlertPresentableAction {
        let locale = localizationManager.selectedLocale
        let createAccountTitle = R.string.localizable
            .accountCreateOptionTitle(preferredLanguages: locale.rLanguages)
        return AlertPresentableAction(title: createAccountTitle) { [weak self] in
            self?.activateCreateAccount(for: chain)
        }
    }

    private func createAccountImportAction(for chain: ChainModel) -> AlertPresentableAction {
        let locale = localizationManager.selectedLocale
        let importAccountTitle = R.string.localizable
            .accountImportOptionTitle(preferredLanguages: locale.rLanguages)
        return AlertPresentableAction(title: importAccountTitle) { [weak self] in
            self?.activateImportAccount(for: chain)
        }
    }

    private func activateCreateAccount(for _: ChainModel) {
        guard let view = previousView else { return }

        accountManagementWireframe.showCreateAccount(
            from: view,
            wallet: metaAccount,
            chainId: crowdloanChainId,
            isEthereumBased: true
        )
    }

    private func activateImportAccount(for _: ChainModel) {
        guard let view = previousView else { return }

        accountManagementWireframe.showImportAccount(
            from: view,
            wallet: metaAccount,
            chainId: crowdloanChainId,
            isEthereumBased: true
        )
    }

    func checkAgreement() {
        let termsOperation = service.createCheckTermsOperation()
        let locale = localizationManager.selectedLocale

        previousView?.didStartLoading()
        termsOperation.completionBlock = { [weak self] in
            DispatchQueue.main.async {
                self?.previousView?.didStopLoading()
                do {
                    let alreadyAgreed = try termsOperation.extractNoCancellableResultData()
                    if alreadyAgreed {
                        self?.showContributionSetup()
                    } else {
                        self?.showTerms()
                    }
                } catch {
                    guard let controller = self?.previousView?.controller else { return }
                    UIAlertController.present(
                        message: R.string.localizable
                            .crowdloanMoonbeamRegionRestrictionMessage(preferredLanguages: locale.rLanguages),
                        title: R.string.localizable
                            .crowdloanMoonbeamRegionRestrictionTitle(preferredLanguages: locale.rLanguages),
                        closeAction: R.string.localizable.commonOk(preferredLanguages: locale.rLanguages),
                        with: controller
                    )
                }
            }
        }
        operationManager.enqueue(operations: [termsOperation], in: .transient)
    }

    func showTerms() {
        guard let termsModule = MoonbeamTermsViewFactory.createView(
            state: state,
            paraId: paraId,
            service: service
        ) else { return }
        let controller = termsModule.controller
        controller.hidesBottomBarWhenPushed = true

        previousView?.controller.navigationController?.pushViewController(controller, animated: true)
    }

    private func showContributionSetup() {
        guard let setupView = CrowdloanContributionSetupViewFactory.createView(
            for: paraId,
            state: state,
            bonusService: service
        ) else {
            return
        }

        let controller = setupView.controller
        controller.hidesBottomBarWhenPushed = true
        previousView?.controller.navigationController?.pushViewController(controller, animated: true)
    }
}
