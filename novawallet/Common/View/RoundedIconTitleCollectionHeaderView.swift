import UIKit
import SnapKit
import SoraUI

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

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func bind(title: String, icon: UIImage?) {
        view.bind(title: title, icon: icon)
    }
}

