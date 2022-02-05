import UIKit

final class AssetsManageViewLayout: UIView {
    let controlTitleLabel: UILabel = {
        let label = UILabel()
        label.font = .regularFootnote
        label.textColor = R.color.colorWhite()
        return label
    }()

    let switchControl: UISwitch = {
        let view = UISwitch()
        view.onTintColor = R.color.colorAccent()
        view.thumbTintColor = R.color.colorWhite()
        return view
    }()

    let applyButton: TriangularedButton = {
        let button = TriangularedButton()
        button.applyDefaultStyle()
        return button
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)

        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupLayout() {
        addSubview(switchControl)
        switchControl.snp.makeConstraints { make in
            make.trailing.equalToSuperview().inset(UIConstants.horizontalInset)
            make.top.equalTo(safeAreaLayoutGuide).offset(29.0)
        }

        addSubview(controlTitleLabel)
        controlTitleLabel.snp.makeConstraints { make in
            make.leading.equalToSuperview().inset(UIConstants.horizontalInset)
            make.centerY.equalTo(switchControl)
            make.trailing.equalTo(switchControl.snp.leading).offset(-8.0)
        }

        addSubview(applyButton)

        applyButton.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(UIConstants.horizontalInset)
            make.bottom.equalTo(safeAreaLayoutGuide).inset(UIConstants.actionBottomInset)
            make.height.equalTo(UIConstants.actionHeight)
        }
    }
}
