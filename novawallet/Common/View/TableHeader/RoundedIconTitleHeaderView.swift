import UIKit
import SnapKit
import UIKit_iOS

final class RoundedIconTitleHeaderView: UITableViewHeaderFooterView {
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

    override init(reuseIdentifier: String?) {
        super.init(reuseIdentifier: reuseIdentifier)

        let backgroundView = UIView()
        backgroundView.backgroundColor = R.color.colorSecondaryScreenBackground()
        self.backgroundView = backgroundView

        contentView.addSubview(view)
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
