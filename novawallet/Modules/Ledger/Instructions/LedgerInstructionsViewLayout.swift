import UIKit
import UIKit_iOS

final class LedgerInstructionsViewLayout: UIView, AdaptiveDesignable {
    let containerView: ScrollableContainerView = {
        let view = ScrollableContainerView(axis: .vertical, respectsSafeArea: true)
        view.stackView.layoutMargins = UIEdgeInsets(top: 12.0, left: 16.0, bottom: 8.0, right: 16.0)
        view.stackView.isLayoutMarginsRelativeArrangement = true
        view.stackView.alignment = .fill
        return view
    }()

    let actionButton: TriangularedButton = {
        let button = TriangularedButton()
        button.applyDefaultStyle()
        return button
    }()

    let titleLabel: UILabel = {
        let label = UILabel()
        label.textColor = R.color.colorTextPrimary()
        label.font = .boldTitle3
        label.numberOfLines = 0
        return label
    }()

    let hintLinkView = LinkView()

    let integrationImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        imageView.image = R.image.imageNovaLedger()
        return imageView
    }()

    let step1: ProcessStepView = {
        let view = ProcessStepView()
        view.stepNumberView.titleLabel.text = "1"
        return view
    }()

    let step2: ProcessStepView = {
        let view = ProcessStepView()
        view.stepNumberView.titleLabel.text = "2"
        return view
    }()

    let step3: ProcessStepView = {
        let view = ProcessStepView()
        view.stepNumberView.titleLabel.text = "3"
        return view
    }()

    let step4: ProcessStepView = {
        let view = ProcessStepView()
        view.stepNumberView.titleLabel.text = "4"
        return view
    }()

    private var migrationBannerView: LedgerMigrationBannerView?

    override init(frame: CGRect) {
        super.init(frame: frame)

        backgroundColor = R.color.colorSecondaryScreenBackground()

        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupMigrationBannerViewIfNeeded() -> LedgerMigrationBannerView {
        if let migrationBannerView {
            return migrationBannerView
        }

        let view = LedgerMigrationBannerView()
        view.apply(style: .warning)
        migrationBannerView = view

        containerView.stackView.addArrangedSubview(view)

        return view
    }

    private func setupLayout() {
        addSubview(actionButton)
        actionButton.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(UIConstants.horizontalInset)
            make.bottom.equalTo(safeAreaLayoutGuide).inset(UIConstants.actionBottomInset)
            make.height.equalTo(UIConstants.actionHeight)
        }

        addSubview(containerView)
        containerView.snp.makeConstraints { make in
            make.top.leading.trailing.equalToSuperview()
            make.bottom.equalTo(actionButton.snp.top).offset(-8.0)
        }

        containerView.stackView.addArrangedSubview(titleLabel)
        containerView.stackView.setCustomSpacing(8.0, after: titleLabel)

        let linkContainerView = UIView()
        linkContainerView.addSubview(hintLinkView)
        hintLinkView.snp.makeConstraints { make in
            make.leading.top.bottom.equalToSuperview()
        }

        containerView.stackView.addArrangedSubview(linkContainerView)
        containerView.stackView.setCustomSpacing(32, after: linkContainerView)

        let imageScaleRatio: CGFloat = isAdaptiveWidthDecreased ? designScaleRatio.width : 1.0
        let integrationImageHeight = 88.0 * imageScaleRatio

        containerView.stackView.addArrangedSubview(integrationImageView)
        integrationImageView.snp.makeConstraints { make in
            make.height.equalTo(integrationImageHeight)
        }

        containerView.stackView.setCustomSpacing(32.0, after: integrationImageView)

        containerView.stackView.addArrangedSubview(step1)

        containerView.stackView.setCustomSpacing(24.0, after: step1)

        containerView.stackView.addArrangedSubview(step2)
        containerView.stackView.setCustomSpacing(24.0, after: step2)

        containerView.stackView.addArrangedSubview(step3)
        containerView.stackView.setCustomSpacing(24.0, after: step3)

        containerView.stackView.addArrangedSubview(step4)
        containerView.stackView.setCustomSpacing(24.0, after: step4)
    }

    func showMigrationBannerView(for viewModel: LedgerMigrationBannerView.ViewModel) {
        let view = setupMigrationBannerViewIfNeeded()
        view.bind(viewModel: viewModel)
    }
}
