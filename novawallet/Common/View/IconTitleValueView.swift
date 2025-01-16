import UIKit
import UIKit_iOS

class IconTitleValueView: UIView {
    let imageView = UIImageView()

    let titleLabel: UILabel = .create {
        $0.apply(style: .footnoteSecondary)
    }

    let valueLabel: UILabel = .create {
        $0.apply(style: .footnotePrimary)
    }

    let borderView = UIFactory.default.createBorderedContainerView()

    override init(frame: CGRect) {
        super.init(frame: frame)

        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupLayout() {
        addSubview(borderView)
        borderView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        addSubview(imageView)
        imageView.snp.makeConstraints { make in
            make.leading.centerY.equalToSuperview()
            make.size.equalTo(16.0)
        }

        addSubview(titleLabel)
        titleLabel.snp.makeConstraints { make in
            make.leading.equalTo(imageView.snp.trailing).offset(8.0)
            make.centerY.equalToSuperview()
        }

        addSubview(valueLabel)
        valueLabel.snp.makeConstraints { make in
            make.trailing.centerY.equalToSuperview()
            make.leading.greaterThanOrEqualTo(titleLabel.snp.trailing).offset(8.0)
        }
    }
}
