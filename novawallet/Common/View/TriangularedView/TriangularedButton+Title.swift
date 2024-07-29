import Foundation

extension TriangularedButton {
    func setTitle(_ title: String?) {
        imageWithTitleView?.title = title
        invalidateLayout()
    }
}
