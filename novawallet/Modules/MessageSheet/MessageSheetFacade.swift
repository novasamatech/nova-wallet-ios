import UIKit
import UIKit_iOS

enum MessageSheetViewFacade {
    static func setupBottomSheet(from controller: UIViewController, preferredHeight: CGFloat) {
        let factory = ModalSheetPresentationFactory(configuration: ModalSheetPresentationConfiguration.nova)

        controller.modalTransitioningFactory = factory
        controller.modalPresentationStyle = .custom

        controller.preferredContentSize = CGSize(width: 0, height: preferredHeight)
    }
}
