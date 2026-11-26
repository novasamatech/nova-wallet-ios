import UIKit
import UIKit_iOS

protocol DAppStakingNoticePresentable {
    func presentStakingNotice(
        from view: ControllerBackedProtocol?,
        context: DAppStakingNoticeContext,
        delegate: DAppStakingNoticeDelegate
    )
}

extension DAppStakingNoticePresentable {
    func presentStakingNotice(
        from view: ControllerBackedProtocol?,
        context: DAppStakingNoticeContext,
        delegate: DAppStakingNoticeDelegate
    ) {
        guard
            let noticeView = DAppStakingNoticeViewFactory.createView(
                for: context,
                delegate: delegate
            )
        else {
            return
        }

        let factory = ModalSheetPresentationFactory(
            configuration: ModalSheetPresentationConfiguration.novaManual
        )
        noticeView.controller.modalTransitioningFactory = factory
        noticeView.controller.modalPresentationStyle = .custom

        view?.controller.present(noticeView.controller, animated: true, completion: nil)
    }
}
