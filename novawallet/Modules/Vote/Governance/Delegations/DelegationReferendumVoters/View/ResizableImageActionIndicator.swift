import UIKit_iOS

final class ResizableImageActionIndicator: ImageActionIndicator {
    var size: CGSize {
        didSet {
            invalidateIntrinsicContentSize()
        }
    }

    init(size: CGSize) {
        self.size = size
        super.init(frame: .zero)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var intrinsicContentSize: CGSize {
        size
    }
}
