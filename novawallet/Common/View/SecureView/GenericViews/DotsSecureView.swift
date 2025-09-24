import Foundation
import UIKit

final class DotsSecureView<View: UIView>: BaseSecureView<View> {
    var privacyModeConfiguration: DotsOverlayView.Configuration = .default

    override func createSecureOverlay() -> UIView? {
        let overlay = DotsOverlayView()
        overlay.configuration = privacyModeConfiguration

        return overlay
    }
}
