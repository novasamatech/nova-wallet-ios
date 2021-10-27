import RobinHood

final class MoonbeamFlowCoordinator: Coordinator {
    let service: MoonbeamBonusServiceProtocol
    let paraId: ParaId
    let operationManager: OperationManagerProtocol
    let previousView: (ControllerBackedProtocol & AlertPresentable)?
    let state: CrowdloanSharedState

    init(
        state: CrowdloanSharedState,
        paraId: ParaId,
        service: MoonbeamBonusServiceProtocol,
        operationManager: OperationManagerProtocol,
        previousView: (ControllerBackedProtocol & AlertPresentable)?
    ) {
        self.state = state
        self.paraId = paraId
        self.service = service
        self.operationManager = operationManager
        self.previousView = previousView
    }

    func start() {
        if service.hasMoonbeamAccount {
            checkHealth()
        } else {
            showMoonbeamAccountAlert()
        }
    }

    func showMoonbeamAccountAlert() {
        // TODO:
    }

    func checkHealth() {
        let healthOperation = service.createCheckHealthOperation()

        healthOperation.completionBlock = { [weak self] in
            DispatchQueue.main.async {
                do {
                    _ = try healthOperation.extractNoCancellableResultData()
                    self?.checkAgreement()
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
        operationManager.enqueue(operations: [healthOperation], in: .transient)
    }

    func checkAgreement() {
        let termsOperation = service.createCheckTermsOperation()

        termsOperation.completionBlock = { [weak self] in
            DispatchQueue.main.async {
                do {
                    let alreadyAgreed = try termsOperation.extractNoCancellableResultData()
                    if alreadyAgreed {
                        self?.showContributionSetup()
                    } else {
                        self?.showTerms()
                    }
                } catch {
                    print(error) // TODO: show error alert
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
