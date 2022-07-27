import UIKit
import SoraUI

final class RoundedIconTitleHeaderView: UITableViewHeaderFooterView {
    let titleView: IconDetailsView = {
        let view = IconDetailsView()
        view.detailsLabel.textColor = R.color.colorWhite80()
        view.detailsLabel.font = .semiBoldCaps1
        view.detailsLabel.numberOfLines = 1
        view.mode = .iconDetails
        view.spacing = 6.0
        view.iconWidth = 16.0
        return view
    }()

    var contentInsets = UIEdgeInsets(top: 4.0, left: 0.0, bottom: 4.0, right: 0.0) {
        didSet {
            if contentInsets != oldValue {
                roundedBackgroundView.snp.updateConstraints { make in
                    make.leading.equalToSuperview().inset(contentInsets.left)
                    make.trailing.lessThanOrEqualToSuperview().inset(contentInsets.right)
                    make.top.equalToSuperview().inset(contentInsets.top)
                    make.bottom.lessThanOrEqualToSuperview().inset(contentInsets.bottom)
                }
            }
        }
    }

    let roundedBackgroundView: RoundedView = {
        let view = RoundedView()
        view.shadowOpacity = 0.0
        view.fillColor = R.color.colorWhite24()!
        view.highlightedFillColor = R.color.colorWhite24()!
        view.cornerRadius = 8.0
        return view
    }()

    override init(reuseIdentifier: String?) {
        super.init(reuseIdentifier: reuseIdentifier)

        backgroundColor = .clear

        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func bind(title: String, icon: UIImage?) {
        titleView.detailsLabel.text = title
        titleView.imageView.image = icon

        setNeedsLayout()
    }

    private func setupLayout() {
        contentView.addSubview(roundedBackgroundView)
        roundedBackgroundView.snp.makeConstraints { make in
            make.leading.equalToSuperview().inset(contentInsets.left)
            make.trailing.lessThanOrEqualToSuperview().inset(contentInsets.right)
            make.top.equalToSuperview().inset(contentInsets.top)
            make.bottom.lessThanOrEqualToSuperview().inset(contentInsets.bottom)
        }

        roundedBackgroundView.addSubview(titleView)
        titleView.snp.makeConstraints { make in
            make.leading.equalToSuperview().inset(6.0)
            make.top.bottom.equalToSuperview().inset(3.0)
            make.trailing.equalToSuperview().inset(8.0)
        }
    }
}
