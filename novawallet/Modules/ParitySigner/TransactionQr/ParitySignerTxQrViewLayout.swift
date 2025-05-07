import UIKit
import UIKit_iOS

final class ParitySignerTxQrViewLayout: UIView, AdaptiveDesignable {
    enum Constants {
        static let qrContentInsets: CGFloat = 10.0
        static let defaultQrSize: CGFloat = 280.0
    }

    let closeBarItem: UIBarButtonItem = {
        let item = UIBarButtonItem(
            image: R.image.iconClose(),
            style: .plain,
            target: nil,
            action: nil
        )

        return item
    }()

    let containerView: ScrollableContainerView = {
        let view = ScrollableContainerView(axis: .vertical, respectsSafeArea: true)
        view.stackView.layoutMargins = UIEdgeInsets(top: 0.0, left: 16.0, bottom: 0.0, right: 16.0)
        view.stackView.isLayoutMarginsRelativeArrangement = true
        view.stackView.alignment = .fill
        return view
    }()

    let accountDetailsView: WalletAccountInfoView = {
        let view = WalletAccountInfoView()
        view.applyOutlineStyle()
        return view
    }()

    let qrTypeSwitch: RoundedSegmentedControl = .create { view in
        view.backgroundView.fillColor = R.color.colorSegmentedBackgroundOnBlack()!
        view.selectionColor = R.color.colorSegmentedTabActive()!
        view.titleFont = .regularFootnote
        view.selectedTitleColor = R.color.colorTextPrimary()!
        view.titleColor = R.color.colorTextSecondary()!
    }

    let qrView = QRDisplayView()

    let timerLabel: UILabel = {
        let label = UILabel()
        label.textColor = R.color.colorTextSecondary()
        label.font = .regularFootnote
        label.textAlignment = .center
        return label
    }()

    let helpButton: TriangularedButton = {
        let button = TriangularedButton()
        button.applySecondaryDefaultStyle()
        return button
    }()

    let continueButton: TriangularedButton = {
        let button = TriangularedButton()
        button.applyDefaultStyle()
        return button
    }()

    var qrSize: CGFloat {
        designScaleRatio.width * 280.0
    }

    var qrImageSize: CGFloat {
        max(qrSize - 2 * Constants.qrContentInsets, 0.0)
    }

    override init(frame: CGRect) {
        super.init(frame: frame)

        backgroundColor = R.color.colorSecondaryScreenBackground()

        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupLayout() {
        let verticalScaling = isAdaptiveWidthDecreased ? designScaleRatio.height * 0.85 : 1.0
        let topOffsetScaling = isAdaptiveWidthDecreased ? verticalScaling * 0.6 : 1.0

        addSubview(continueButton)
        continueButton.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(UIConstants.horizontalInset)
            make.bottom.equalTo(safeAreaLayoutGuide.snp.bottom).offset(-UIConstants.actionBottomInset * verticalScaling)
            make.height.equalTo(UIConstants.actionHeight)
        }

        addSubview(helpButton)
        helpButton.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(UIConstants.horizontalInset * verticalScaling)
            make.height.equalTo(UIConstants.actionHeight)
            make.bottom.equalTo(continueButton.snp.top).offset(-16.0 * verticalScaling)
        }

        var layoutMargins = containerView.stackView.layoutMargins
        layoutMargins.top = 16.0 * topOffsetScaling
        containerView.stackView.layoutMargins = layoutMargins

        addSubview(containerView)
        containerView.snp.makeConstraints { make in
            make.top.equalTo(safeAreaLayoutGuide.snp.top)
            make.leading.trailing.equalToSuperview()
            make.bottom.equalTo(helpButton.snp.top).offset(-16.0 * verticalScaling)
        }

        containerView.stackView.addArrangedSubview(accountDetailsView)
        accountDetailsView.snp.makeConstraints { make in
            make.height.equalTo(52.0)
        }

        containerView.stackView.setCustomSpacing(32.0 * topOffsetScaling, after: accountDetailsView)

        containerView.stackView.addArrangedSubview(qrTypeSwitch)
        qrTypeSwitch.snp.makeConstraints { make in
            make.height.equalTo(40)
        }

        containerView.stackView.setCustomSpacing(24.0 * verticalScaling, after: qrTypeSwitch)

        let qrContainerView = UIView()
        qrContainerView.backgroundColor = .clear

        containerView.stackView.addArrangedSubview(qrContainerView)
        qrContainerView.snp.makeConstraints { make in
            make.height.equalTo(qrSize)
        }

        qrContainerView.addSubview(qrView)
        qrView.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.size.equalTo(qrSize)
        }

        containerView.stackView.setCustomSpacing(24.0 * verticalScaling, after: qrContainerView)

        containerView.stackView.addArrangedSubview(timerLabel)
    }
}
