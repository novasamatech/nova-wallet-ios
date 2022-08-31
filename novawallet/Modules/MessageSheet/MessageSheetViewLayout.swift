import UIKit

final class MessageSheetViewLayout<
    I: UIView & MessageSheetGraphicsProtocol,
    C: UIView & MessageSheetContentProtocol
>: UIView {
    let graphicsView = I()

    let contentView = C()

    let titleLabel: UILabel = {
        let label = UILabel()
        label.textColor = R.color.colorWhite()
        label.font = .semiBoldTitle3
        label.textAlignment = .center
        return label
    }()

    let detailsLabel: UILabel = {
        let label = UILabel()
        label.textColor = R.color.colorTransparentText()
        label.font = .regularFootnote
        label.textAlignment = .center
        label.numberOfLines = 0
        return label
    }()

    private(set) var mainActionButton: TriangularedButton?
    private(set) var secondaryActionButton: TriangularedButton?
    private(set) var buttonsStackView: UIStackView?

    override init(frame: CGRect) {
        super.init(frame: frame)

        backgroundColor = R.color.color0x1D1D20()

        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupButtonsStackViewIfNeeded() {
        guard buttonsStackView == nil else {
            return
        }

        let stackView = UIStackView()
        stackView.axis = .horizontal
        stackView.isLayoutMarginsRelativeArrangement = true
        stackView.layoutMargins = UIEdgeInsets(top: 0.0, left: 16.0, bottom: 0.0, right: 16.0)
        stackView.distribution = .fillEqually
        stackView.alignment = .fill
        stackView.spacing = 12.0

        addSubview(stackView)
        stackView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
            make.bottom.equalTo(safeAreaLayoutGuide.snp.bottom).offset(-16.0)
            make.height.equalTo(UIConstants.actionHeight)
        }

        buttonsStackView = stackView
    }

    func setupMainActionButton() {
        setupButtonsStackViewIfNeeded()

        let button = TriangularedButton()
        button.applyDefaultStyle()

        buttonsStackView?.addArrangedSubview(button)

        mainActionButton = button
    }

    func setupSecondaryActionButton() {
        setupButtonsStackViewIfNeeded()

        let button = TriangularedButton()
        button.applySecondaryDefaultStyle()

        buttonsStackView?.insertArrangedSubview(button, at: 0)

        secondaryActionButton = button
    }

    private func setupLayout() {
        addSubview(graphicsView)
        graphicsView.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.top.equalToSuperview().inset(16.0)
        }

        addSubview(titleLabel)
        titleLabel.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(16.0)
            make.top.equalTo(graphicsView.snp.bottom).offset(24.0)
        }

        addSubview(detailsLabel)
        detailsLabel.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(16.0)
            make.top.equalTo(titleLabel.snp.bottom).offset(8.0)
        }

        addSubview(contentView)
        contentView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(16.0)
            make.top.equalTo(detailsLabel.snp.bottom).offset(40.0)
        }
    }
}
