import Foundation
import UIKit_iOS

extension RoundedButton {
    func setTitle(_ title: String?) {
        imageWithTitleView?.title = title
        invalidateLayout()
    }

    func bindIconWithTitle(viewModel: IconWithTitleViewModel) {
        imageWithTitleView?.title = viewModel.title
        imageWithTitleView?.iconImage = viewModel.icon

        invalidateLayout()
    }
}
