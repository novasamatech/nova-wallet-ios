import UIKit
import UIKit_iOS

protocol DAppStakingNoticePresentable {
    func presentStakingNotice(
        from view: ControllerBackedProtocol?,
        delegate: DAppStakingNoticeDelegate
    )
}

extension DAppStakingNoticePresentable {
    func presentStakingNotice(
        from view: ControllerBackedProtocol?,
        delegate: DAppStakingNoticeDelegate
    ) {
        guard let noticeView = DAppStakingNoticeViewFactory.createView(with: delegate) else {
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
