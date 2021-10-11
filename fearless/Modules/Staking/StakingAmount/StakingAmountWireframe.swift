import Foundation
import SoraFoundation

final class StakingAmountWireframe: StakingAmountWireframeProtocol {
    let stakingState: StakingSharedState

    init(stakingState: StakingSharedState) {
        self.stakingState = stakingState
    }

    func presentAccountSelection(
        _ accounts: [AccountItem],
        selectedAccountItem: AccountItem,
        delegate: ModalPickerViewControllerDelegate,
        from view: StakingAmountViewProtocol?,
        context: AnyObject?
    ) {
        let title = LocalizableResource { locale in
            R.string.localizable
                .stakingRewardPayoutAccount(preferredLanguages: locale.rLanguages)
        }

        guard let picker = ModalPickerFactory.createPickerList(
            accounts,
            selectedAccount: selectedAccountItem,
            title: title,
            delegate: delegate,
            context: context
        ) else {
            return
        }

        view?.controller.present(picker, animated: true, completion: nil)
    }

    func proceed(from view: StakingAmountViewProtocol?, state: InitiatedBonding) {
        guard let validatorsView = SelectValidatorsStartViewFactory.createInitiatedBondingView(
            with: state,
            stakingState: stakingState
        ) else {
            return
        }

        view?.controller.navigationController?.pushViewController(
            validatorsView.controller,
            animated: true
        )
    }

    func close(view: StakingAmountViewProtocol?) {
        view?.controller.presentingViewController?.dismiss(animated: true, completion: nil)
    }
}
