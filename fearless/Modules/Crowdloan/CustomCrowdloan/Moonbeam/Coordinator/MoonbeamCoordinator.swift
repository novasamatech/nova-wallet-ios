import RobinHood

final class MoonbeamFlowCoordinator: Coordinator {
    let service: MoonbeamBonusServiceProtocol
    let paraId: ParaId
    let operationManager: OperationManagerProtocol
    let previousView: (ControllerBackedProtocol & AlertPresentable & LoadableViewProtocol)?
    let state: CrowdloanSharedState

    init(
        state: CrowdloanSharedState,
        paraId: ParaId,
        service: MoonbeamBonusServiceProtocol,
        operationManager: OperationManagerProtocol,
        previousView: (ControllerBackedProtocol & AlertPresentable & LoadableViewProtocol)?
    ) {
        self.state = state
        self.paraId = paraId
        self.service = service
        self.operationManager = operationManager
        self.previousView = previousView
    }

    func start() {
        if service.hasMoonbeamAccount {
            checkAgreement()
        } else {
            showMoonbeamAccountAlert()
        }
    }

    func showMoonbeamAccountAlert() {
        let viewModel = AlertPresentableViewModel(
            title: "Moonbeam account is missing",
            message: "You should add Moonbeam account to the wallet in order to participate in Moonbeam crowdloan",
            actions: [
                .init(
                    title: "Cancel",
                    style: .destructive
                ),
                .init(
                    title: "Add",
                    style: .normal,
                    handler: { [weak self] in
                        self?.showAddAccount()
                    }
                )
            ],
            closeAction: nil
        )
        previousView?.present(viewModel: viewModel, style: .alert, from: previousView)
    }

    func showAddAccount() {
        guard let onboarding = OnboardingMainViewFactory.createViewForAccountSwitch() else {
            return
        }
        onboarding.controller.hidesBottomBarWhenPushed = true
        previousView?.controller
            .navigationController?.pushViewController(onboarding.controller, animated: true)
    }

    func checkAgreement() {
        let termsOperation = service.createCheckTermsOperation()

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
                        message: "This crowdloan isn't available in your location.",
                        title: "Your region is not supported",
                        closeAction: "OK",
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
