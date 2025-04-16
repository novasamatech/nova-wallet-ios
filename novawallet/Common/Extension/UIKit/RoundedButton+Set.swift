import Foundation
import UIKit_iOS

extension RoundedButton {
    func setTitle(_ title: String?) {
        imageWithTitleView?.title = title
        invalidateLayout()
    }
}
