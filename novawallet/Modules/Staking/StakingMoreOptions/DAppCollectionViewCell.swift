import UIKit
import SnapKit

final class DAppCollectionViewCell: UICollectionViewCell {
    let bodyView = ReferendumDAppView()

    override init(frame: CGRect) {
        super.init(frame: frame)

        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    var contentInsets: UIEdgeInsets = .zero {
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
