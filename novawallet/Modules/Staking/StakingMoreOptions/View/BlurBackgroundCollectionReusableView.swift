import UIKit
import SnapKit

final class BlurBackgroundCollectionReusableView: UICollectionReusableView {
    static var reuseId: String { String(describing: Self.self) }

    let backgroundBlurView = BlockBackgroundView()

    var contentInsets: UIEdgeInsets = .zero {
        didSet {
            updateLayout()
        }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)

        backgroundColor = .clear
        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupLayout() {
        addSubview(backgroundBlurView)
        backgroundBlurView.snp.makeConstraints {
            $0.edges.equalToSuperview().inset(contentInsets)
        }
    }

    private func updateLayout() {
        backgroundBlurView.snp.updateConstraints {
            $0.edges.equalToSuperview().inset(contentInsets)
        }
    }
}
