import Foundation
import Foundation_iOS
import UIKit
import UIKit_iOS

final class SubtensorStakingSetupWireframe: SubtensorStakingSetupWireframeProtocol {
    let state: SubtensorStakingSharedStateProtocol

    init(state: SubtensorStakingSharedStateProtocol) {
        self.state = state
    }

    func showConfirmation(
        from view: CollatorStakingSetupViewProtocol?,
        model: SubtensorStakingConfirmModel
    ) {
        guard let confirmView = SubtensorStakingConfirmViewFactory.createView(
            for: state,
            model: model
        ) else {
            return
        }

        view?.controller.navigationController?.pushViewController(confirmView.controller, animated: true)
    }

    func showValidatorSelection(
        from view: CollatorStakingSetupViewProtocol?,
        target: SubtensorStakeTarget,
        delegate: SubtensorSubnetSelectDelegate
    ) {
        guard let selectView = SubtensorValidatorSelectViewFactory.createView(
            for: state,
            target: target,
            delegate: delegate
        ) else {
            return
        }

        view?.controller.navigationController?.pushViewController(selectView.controller, animated: true)
    }

    func showSubnetRiskNote(
        from view: CollatorStakingSetupViewProtocol?,
        onContinue: @escaping () -> Void
    ) {
        let continueAction = MessageSheetAction(
            title: LocalizableResource { locale in
                R.string(preferredLanguages: locale.rLanguages).localizable.commonContinue()
            },
            handler: onContinue
        )

        let cancelAction = MessageSheetAction(
            title: LocalizableResource { locale in
                R.string(preferredLanguages: locale.rLanguages).localizable.commonCancel()
            },
            handler: {}
        )

        let viewModel = TitleDetailsSheetViewModel(
            title: LocalizableResource { locale in
                R.string(preferredLanguages: locale.rLanguages).localizable.stakingSubtensorSubnetRiskTitle()
            },
            message: LocalizableResource { locale in
                R.string(
                    preferredLanguages: locale.rLanguages
                ).localizable.stakingSubtensorSubnetRiskMessage()
            },
            mainAction: continueAction,
            secondaryAction: cancelAction
        )

        let bottomSheet = TitleDetailsSheetViewFactory.createView(
            from: viewModel,
            allowsSwipeDown: true,
            preferredContentSize: CGSize(width: 0.0, height: 300.0)
        )

        let factory = ModalSheetPresentationFactory(
            configuration: ModalSheetPresentationConfiguration.novaManual
        )

        bottomSheet.controller.modalTransitioningFactory = factory
        bottomSheet.controller.modalPresentationStyle = .custom

        view?.controller.present(bottomSheet.controller, animated: true)
    }

    func showSubnetSelection(
        from view: CollatorStakingSetupViewProtocol?,
        delegate: SubtensorSubnetSelectDelegate,
        delegateTake: UInt16?
    ) {
        guard let selectView = SubtensorSubnetSelectViewFactory.createView(
            for: state,
            delegate: delegate,
            delegateTake: delegateTake
        ) else {
            return
        }

        view?.controller.navigationController?.pushViewController(selectView.controller, animated: true)
    }

    func showSlippageEdit(
        from view: CollatorStakingSetupViewProtocol?,
        current: BigRational,
        completion: @escaping (BigRational) -> Void
    ) {
        guard let slippageView = SwapSlippageViewFactory.createSubtensorView(
            percent: current,
            chainAsset: state.stakingOption.chainAsset,
            completionHandler: completion
        ) else {
            return
        }

        view?.controller.navigationController?.pushViewController(
            slippageView.controller,
            animated: true
        )
    }
}
