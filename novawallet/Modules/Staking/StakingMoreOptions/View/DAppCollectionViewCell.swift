import UIKit
import SnapKit

final class DAppCollectionViewCell: UICollectionViewCell {
    let bodyView = DAppView()

    override init(frame: CGRect) {
        super.init(frame: frame)

        setupLayout()
        bodyView.arrowView.isHidden = true
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    var contentInsets: UIEdgeInsets = .init(top: 0, left: 16, bottom: 0, right: 16) {
        didSet {
            bodyView.snp.updateConstraints {
                $0.edges.equalToSuperview().inset(contentInsets)
            }
        }
    }

    private func setupLayout() {
        contentView.addSubview(bodyView)
        bodyView.snp.makeConstraints {
            $0.edges.equalToSuperview().inset(contentInsets)
        }
    }
}
