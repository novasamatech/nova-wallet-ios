import UIKit

final class YourWalletsViewLayout: UIView {
    override init(frame: CGRect) {
        super.init(frame: frame)

        backgroundColor = R.color.color0x1D1D20()
        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupLayout() {
    }
}
