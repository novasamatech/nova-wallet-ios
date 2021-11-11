import UIKit

final class SettingsTableHeaderView: UIView {
    let titleLabel: UILabel = {
        let label = UILabel()
        label.textColor = R.color.colorWhite()
        label.font = .h1Title
        return label
    }()

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
        addSubview(titleLabel)
        titleLabel.snp.makeConstraints { make in
            make.top.equalToSuperview().inset(10)
            make.height.equalTo(41)
            make.leading.equalToSuperview().inset(16)
            make.bottom.equalToSuperview()
        }
    }
}
