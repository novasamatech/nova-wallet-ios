import Foundation
import Foundation_iOS

extension SubtensorStakeSetupPresenter {
    func loadQuickPick() {
        guard let quickPickVisit, !quickPickVisit.isManuallyReplaced, target == nil else { return }
        quickPickVisit.beginRequest()
        provideViewModel()
        interactor.loadQuickPickSnapshot(for: quickPickVisit.order, selectedRef: quickPickVisit.selectedRef)
    }

    func retryQuickPick() {
        guard quickPickVisit?.isLoading == false else { return }
        loadQuickPick()
    }

    func didReceiveQuickPickSnapshot(_ result: Result<SubtensorQuickPickSnapshot, Error>) {
        guard let quickPickVisit, !quickPickVisit.isManuallyReplaced, target == nil else { return }
        if let target = quickPickVisit.resolve(result) {
            trackQuickPickSelected(target, order: quickPickVisit.order)
            mode = .subnetPick(target: target, validator: nil)
            startMode()
        } else {
            provideViewModel()
        }
    }

    func showAllSubnets() {
        guard !mode.isLocked else { return }
        wireframe.showAllSubnets(from: view, browseState: browseState, delegate: self, source: subnetListSource)
    }
}

extension SubtensorStakeSetupPresenter: Localizable {
    func applyLocalization() {
        if let view, view.isSetup {
            provideAmountInputViewModel()
            provideAssetViewModel()
            provideViewModel()
        }
    }
}
