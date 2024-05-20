import UIKit

class MnemonicWordCollectionCell: BlurredCollectionViewCell<UILabel> {
    override init(frame: CGRect) {
        super.init(frame: frame)

        setupLayout()
        setupStyle()
    }

    func setupLayout() {
        view.contentInsets = .zero
        view.innerInsets = .init(top: 0, left: 8, bottom: 0, right: 8)
    }

    func setupStyle() {
        view.view.apply(style: .regularSubhedlinePrimary)
    }
}
