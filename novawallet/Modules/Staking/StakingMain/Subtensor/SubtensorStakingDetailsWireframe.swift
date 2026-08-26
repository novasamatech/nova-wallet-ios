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

    func showUnstakeTokens(
        from view: ControllerBackedProtocol?,
        initialPosition: SubtensorStakingPosition?
    ) {
        guard let unstakeView = SubtensorUnstakeSetupViewFactory.createView(
            for: state,
            initialPosition: initialPosition
        ) else {
            return
        }

        let navigationController = ImportantFlowViewFactory.createNavigation(from: unstakeView.controller)

        view?.controller.presentWithCardLayout(
            navigationController,
            animated: true
        )
    }

    func showUnstakePositionSelection(
        from view: ControllerBackedProtocol?,
        viewModels: [AccountDetailsPickerViewModel],
        delegate: ModalPickerViewControllerDelegate,
        context: AnyObject?
    ) {
        let optPositionList: ModalPickerViewController<
            AccountDetailsGenericSelectionCell<AccountDetailsBalanceDecorator>,
            SelectableViewModel<AccountDetailsSelectionViewModel>
        >? = ModalPickerFactory.createGenericCollatorsPickingList(
            viewModels,
            actionViewModel: nil,
            selectedIndex: NSNotFound,
            delegate: delegate,
            context: context
        )

        guard let positionList = optPositionList else {
            return
        }

        positionList.localizedTitle = LocalizableResource { locale in
            R.string(preferredLanguages: locale.rLanguages).localizable.stakingUnbond_v190()
        }

        view?.controller.present(positionList, animated: true, completion: nil)
    }

    func showPositionList(
        from view: ControllerBackedProtocol?,
        viewModels: [AccountDetailsPickerViewModel],
        showsCompoundingNote: Bool
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

        if showsCompoundingNote {
            // a trailing row-less section renders footer-only, which keeps the note out of every
            // row without touching the shared picker factory
            positionList.addSection(
                viewModels: [],
                title: nil,
                footer: LocalizableResource { locale in
                    R.string(
                        preferredLanguages: locale.rLanguages
                    ).localizable.stakingSubtensorPositionsCompoundFooter()
                }
            )

            positionList.preferredContentSize.height += positionList.sectionFooterHeight
        }

        view?.controller.present(positionList, animated: true, completion: nil)
    }
}
