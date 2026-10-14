import Foundation
import Foundation_iOS

extension SubtensorStakingSetupPresenter {
    func loadQuickPick(forcingRefresh: Bool) {
        guard let quickPickVisit, !quickPickVisit.isManuallyReplaced, target == nil else { return }
        let generation = quickPickVisit.beginRequest()
        provideViewModel()
        interactor.loadQuickPickSnapshot(generation: generation, forcingRefresh: forcingRefresh)
    }

    func retryQuickPick() {
        guard quickPickVisit?.isLoading == false else { return }
        loadQuickPick(forcingRefresh: true)
    }

    func didReceiveQuickPickSnapshot(_ result: Result<SubtensorSubnetsInfo, Error>, generation: Int) {
        guard let quickPickVisit, !quickPickVisit.isManuallyReplaced, target == nil else { return }
        if let target = quickPickVisit.resolve(result, generation: generation) {
            mode = .subnetPick(target: target, validator: nil)
            startMode()
        } else {
            provideViewModel()
        }
    }

    func showAllSubnets() {
        guard !mode.isLocked else { return }
        wireframe.showAllSubnets(from: view, browseState: browseState, delegate: self)
    }
}

extension SubtensorStakingSetupPresenter: Localizable {
    func applyLocalization() {
        if let view, view.isSetup {
            provideAmountInputViewModel()
            provideAssetViewModel()
            provideViewModel()
        }
    }
}
