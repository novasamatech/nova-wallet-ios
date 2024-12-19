import Foundation
import SoraUI

extension RoundedButton {
    func setTitle(_ title: String?) {
        imageWithTitleView?.title = title
        invalidateLayout()
    }
}
