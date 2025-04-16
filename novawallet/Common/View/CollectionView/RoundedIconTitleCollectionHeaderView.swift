import UIKit
import SnapKit
import UIKit_iOS

final class RoundedIconTitleCollectionHeaderView: UICollectionReusableView {
    private let view = RoundedIconTitleView()

    var contentInsets: UIEdgeInsets {
        get {
            view.contentInsets
        }
        set {
            view.contentInsets = newValue
        }
    }

    var titleView: IconDetailsView {
        view.titleView
    }

    var roundedBackgroundView: RoundedView {
        view.roundedBackgroundView
    }

    override init(frame: CGRect) {
        super.init(frame: frame)

        backgroundColor = .clear

        addSubview(view)
        view.snp.makeConstraints {
            $0.edges.equalToSuperview()
        }
    }

    override var intrinsicContentSize: CGSize {
        .init(width: UIView.noIntrinsicMetric, height: 22)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

// MARK: - Model

extension RoundedIconTitleCollectionHeaderView {
    struct Model {
        let title: String
        let icon: UIImage?
    }

    func bind(viewModel: Model) {
        view.bind(title: viewModel.title, icon: viewModel.icon)
    }
}
