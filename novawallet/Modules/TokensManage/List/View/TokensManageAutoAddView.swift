import UIKit

final class TokensManageAutoAddView: UIView {
    let titleLabel: UILabel = .create { view in
        view.apply(style: .regularSubhedlinePrimary)
    }

    let switchView: UISwitch = .create { view in
        view.onTintColor = R.color.colorIconAccent()
    }

    override var intrinsicContentSize: CGSize {
        CGSize(width: UIView.noIntrinsicMetric, height: Constants.height)
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

    func bind(isOn: Bool) {
        guard isOn != switchView.isOn else {
            return
        }

        switchView.setOn(isOn, animated: false)
    }
}

// MARK: Private

private extension TokensManageAutoAddView {
    func setupLayout() {
        addSubview(switchView)
        switchView.snp.makeConstraints { make in
            make.trailing.equalToSuperview().inset(Constants.horizontalInset)
            make.centerY.equalToSuperview()
        }

        addSubview(titleLabel)
        titleLabel.snp.makeConstraints { make in
            make.leading.equalToSuperview().inset(Constants.horizontalInset)
            make.trailing.equalTo(switchView.snp.leading).offset(-Constants.contentSpacing)
            make.centerY.equalToSuperview()
        }
    }
}

// MARK: Constants

extension TokensManageAutoAddView {
    enum Constants {
        static let height: CGFloat = 56
        static let horizontalInset: CGFloat = 20
        static let contentSpacing: CGFloat = 12
    }
}
