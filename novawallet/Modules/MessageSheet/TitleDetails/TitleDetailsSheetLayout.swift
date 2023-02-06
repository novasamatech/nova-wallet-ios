import UIKit

final class TitleDetailsSheetViewLayout: UIView {
    let titleLabel: UILabel = .create {
        $0.apply(style: .bottomSheetTitle)
        $0.numberOfLines = 0
    }

    let detailsLabel: UILabel = .create {
        $0.apply(style: .footnoteSecondary)
        $0.numberOfLines = 0
    }

    private(set) var mainActionButton: TriangularedButton?
    private(set) var secondaryActionButton: TriangularedButton?
    private(set) var buttonsStackView: UIStackView?

    override init(frame: CGRect) {
        super.init(frame: frame)

        backgroundColor = R.color.colorBottomSheetBackground()

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
        stackView.spacing = 16.0

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
        let stackView = UIView.vStack(spacing: 10, [titleLabel, detailsLabel])

        addSubview(stackView)
        stackView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(16.0)
            make.top.equalToSuperview().inset(10)
        }
    }
}
