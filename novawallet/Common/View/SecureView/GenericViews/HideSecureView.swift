import Foundation
import UIKit

final class HideSecureView<View: UIView>: BaseSecureView<View> {
    override func createSecureOverlay() -> UIView? {
        nil
    }
}
