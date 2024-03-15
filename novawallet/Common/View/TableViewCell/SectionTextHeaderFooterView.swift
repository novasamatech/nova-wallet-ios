import UIKit

class SectionTextHeaderFooterView: UITableViewHeaderFooterView {
    var horizontalOffset: CGFloat = 20 {
        didSet {
            titleLabel.snp.updateConstraints { make in
                make.leading.trailing.equalToSuperview().inset(horizontalOffset)
            }
        }
    }

    var bottomOffset: CGFloat = 12 {
        didSet {
            titleLabel.snp.updateConstraints { make in
                make.bottom.equalToSuperview().inset(bottomOffset)
            }
        }
    }

    let titleLabel: UILabel = {
        let label = UILabel()
        label.textColor = R.color.colorTextSecondary()
        label.font = .semiBoldCaps2
        return label
    }()

    override init(reuseIdentifier: String?) {
        super.init(reuseIdentifier: reuseIdentifier)

        backgroundView = UIView()
        backgroundView?.backgroundColor = .clear
        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func setupLayout() {
        contentView.addSubview(titleLabel)
        titleLabel.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(horizontalOffset)
            make.bottom.equalToSuperview().inset(bottomOffset)
        }
    }

    func bind(text: String) {
        titleLabel.text = text.uppercased()
    }
}
