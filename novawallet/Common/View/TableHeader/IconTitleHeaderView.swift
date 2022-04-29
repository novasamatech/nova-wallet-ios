import UIKit
import SoraUI

final class IconTitleHeaderView: UITableViewHeaderFooterView {
    let titleView: IconDetailsView = {
        let view = IconDetailsView()
        view.detailsLabel.textColor = R.color.colorWhite()
        view.detailsLabel.font = .semiBoldBody
        view.spacing = 0.0
        return view
    }()

    var contentInsets = UIEdgeInsets(top: 4.0, left: 0.0, bottom: 4.0, right: 0.0) {
        didSet {
            if contentInsets != oldValue {
                titleView.snp.updateConstraints { make in
                    make.leading.equalToSuperview().inset(contentInsets.left)
                    make.trailing.equalToSuperview().inset(contentInsets.right)
                    make.top.equalToSuperview().inset(contentInsets.top)
                    make.bottom.equalToSuperview().inset(contentInsets.bottom)
                }
            }
        }
    }

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
        contentView.addSubview(titleView)
        titleView.snp.makeConstraints { make in
            make.leading.equalToSuperview().inset(contentInsets.left)
            make.trailing.equalToSuperview().inset(contentInsets.right)
            make.top.equalToSuperview().inset(contentInsets.top)
            make.bottom.equalToSuperview().inset(contentInsets.bottom)
        }
    }
}
