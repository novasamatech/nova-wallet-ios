import Foundation
import Foundation_iOS

final class SubtensorStakingDetailsWireframe: SubtensorStakingDetailsWireframeProtocol {
    let state: SubtensorStakingSharedStateProtocol

    init(state: SubtensorStakingSharedStateProtocol) {
        self.state = state
    }

    func showStakeTokens(
        from view: ControllerBackedProtocol?,
        initialPosition: SubtensorStakingPosition?
    ) {
        guard let stakeView = SubtensorStakingSetupViewFactory.createView(
            for: state,
            initialPosition: initialPosition
        ) else {
            return
        }

        let navigationController = ImportantFlowViewFactory.createNavigation(from: stakeView.controller)

        view?.controller.presentWithCardLayout(
            navigationController,
            animated: true
        )
    }

    func showUnstakeTokens(from view: ControllerBackedProtocol?) {
        guard let unstakeView = SubtensorUnstakeSetupViewFactory.createView(
            for: state,
            initialPosition: nil
        ) else {
            return
        }

        let navigationController = ImportantFlowViewFactory.createNavigation(from: unstakeView.controller)

        view?.controller.presentWithCardLayout(
            navigationController,
            animated: true
        )
    }

    func showPositionList(
        from view: ControllerBackedProtocol?,
        viewModels: [AccountDetailsPickerViewModel]
    ) {
        let optPositionList: ModalPickerViewController<
            AccountDetailsGenericSelectionCell<AccountDetailsBalanceDecorator>,
            SelectableViewModel<AccountDetailsSelectionViewModel>
        >? = ModalPickerFactory.createGenericCollatorsPickingList(
            viewModels,
            actionViewModel: nil,
            selectedIndex: NSNotFound,
            delegate: nil,
            context: nil
        )

        guard let positionList = optPositionList else {
            return
        }

        positionList.localizedTitle = LocalizableResource { locale in
            R.string(preferredLanguages: locale.rLanguages).localizable.stakingYourValidatorsTitle()
        }

        view?.controller.present(positionList, animated: true, completion: nil)
    }
}
