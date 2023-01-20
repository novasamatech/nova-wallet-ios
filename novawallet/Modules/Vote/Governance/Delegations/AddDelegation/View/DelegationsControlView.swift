import UIKit

final class DelegationsControlView: UIView {
    let label = UILabel(style: .footnoteSecondary)
    let control: YourWalletsControl = .create {
        $0.color = R.color.colorTextPrimary()!
        $0.iconDetailsView.detailsLabel.apply(style: .footnotePrimary)
    }

    override init(frame: CGRect) {
        super.init(frame: frame)

        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupLayout() {
        addSubview(label)
        addSubview(control)

        label.snp.makeConstraints {
            $0.leading.top.bottom.equalToSuperview()
        }

        control.snp.makeConstraints {
            $0.leading.equalTo(label.snp.trailing)
            $0.centerY.trailing.equalToSuperview()
        }
    }

    func bind(title: String, value: String) {
        label.text = title
        control.iconDetailsView.detailsLabel.text = value
    }
}
