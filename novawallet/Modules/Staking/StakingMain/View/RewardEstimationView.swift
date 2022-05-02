import UIKit
import CommonWallet
import SoraFoundation
import SoraUI

protocol RewardEstimationViewDelegate: AnyObject {
    func rewardEstimationDidStartAction(_ view: RewardEstimationView)
    func rewardEstimationDidRequestInfo(_ view: RewardEstimationView)
}

final class RewardEstimationView: LocalizableView {
    let backgroundView: TriangularedBlurView = {
        let view = TriangularedBlurView()
        return view
    }()

    let titleLabel: UILabel = {
        let label = UILabel()
        label.textColor = R.color.colorWhite()
        label.font = .regularSubheadline
        return label
    }()

    let monthlyTitleLabel: UILabel = {
        let label = UILabel()
        label.textColor = R.color.colorTransparentText()
        label.font = .regularFootnote
        return label
    }()

    let monthlyValueLabel: UILabel = {
        let label = UILabel()
        label.textColor = R.color.colorGreen()
        label.font = .title2
        return label
    }()

    let yearlyTitleLabel: UILabel = {
        let label = UILabel()
        label.textColor = R.color.colorTransparentText()
        label.font = .regularFootnote
        return label
    }()

    let yearlyValueLabel: UILabel = {
        let label = UILabel()
        label.textColor = R.color.colorGreen()
        label.font = .title2
        return label
    }()

    let mainButton: TriangularedButton = {
        let button = TriangularedButton()
        button.applyDefaultStyle()
        return button
    }()

    let infoButton: RoundedButton = {
        let button = RoundedButton()
        button.applyIconStyle()
        button.imageWithTitleView?.iconImage = R.image.iconInfo()?.withRenderingMode(.alwaysTemplate)
        button.tintColor = R.color.colorWhite48()!
        return button
    }()

    private var skeletonView: SkrullableView?

    var actionTitle: LocalizableResource<String> = LocalizableResource { locale in
        R.string.localizable.stakingStartTitle(preferredLanguages: locale.rLanguages)
    } {
        didSet {
            applyActionTitle()
        }
    }

    weak var delegate: RewardEstimationViewDelegate?

    var locale = Locale.current {
        didSet {
            applyLocalization()

            if widgetViewModel != nil {
                applyWidgetViewModel()
            }
        }
    }

    private var widgetViewModel: StakingEstimationViewModel?

    override init(frame: CGRect) {
        super.init(frame: frame)

        setupLayout()

        mainButton.addTarget(
            self,
            action: #selector(actionMainTouchUpInside),
            for: .touchUpInside
        )

        infoButton.addTarget(
            self,
            action: #selector(actionInfoTouchUpInside),
            for: .touchUpInside
        )
    }

    override var intrinsicContentSize: CGSize {
        CGSize(width: UIView.noIntrinsicMetric, height: 202.0)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        if skeletonView != nil {
            setupSkeleton()
        }
    }

    func bind(viewModel: StakingEstimationViewModel) {
        widgetViewModel = viewModel
        applyWidgetViewModel()
    }

    private func setupLayout() {
        addSubview(backgroundView)
        backgroundView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        addSubview(infoButton)
        infoButton.snp.makeConstraints { make in
            make.trailing.equalToSuperview()
            make.top.equalToSuperview()
            make.width.equalTo(56.0)
            make.height.equalTo(48.0)
        }

        addSubview(titleLabel)
        titleLabel.snp.makeConstraints { make in
            make.leading.equalToSuperview().inset(16.0)
            make.top.equalToSuperview().inset(14.0)
        }

        addSubview(mainButton)
        mainButton.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(UIConstants.horizontalInset)
            make.bottom.equalToSuperview().inset(24.0)
            make.height.equalTo(UIConstants.actionHeight)
        }

        addSubview(monthlyTitleLabel)
        monthlyTitleLabel.snp.makeConstraints { make in
            make.leading.greaterThanOrEqualToSuperview().inset(16)
            make.trailing.lessThanOrEqualTo(self.snp.centerX).offset(-16.0)
            make.centerX.equalToSuperview().multipliedBy(0.5)
            make.bottom.equalTo(mainButton.snp.top).offset(-24.0)
        }

        addSubview(yearlyTitleLabel)
        yearlyTitleLabel.snp.makeConstraints { make in
            make.leading.greaterThanOrEqualTo(self.snp.centerX).offset(16.0)
            make.trailing.lessThanOrEqualToSuperview().offset(-16.0)
            make.centerX.equalToSuperview().multipliedBy(1.5)
            make.bottom.equalTo(mainButton.snp.top).offset(-24.0)
        }

        addSubview(monthlyValueLabel)
        monthlyValueLabel.snp.makeConstraints { make in
            make.leading.greaterThanOrEqualToSuperview().inset(16)
            make.trailing.lessThanOrEqualTo(self.snp.centerX).offset(-16.0)
            make.centerX.equalToSuperview().multipliedBy(0.5)
            make.bottom.equalTo(monthlyTitleLabel.snp.top).offset(-2.0)
        }

        addSubview(yearlyValueLabel)
        yearlyValueLabel.snp.makeConstraints { make in
            make.leading.greaterThanOrEqualTo(self.snp.centerX).offset(16.0)
            make.trailing.lessThanOrEqualToSuperview().offset(-16.0)
            make.centerX.equalToSuperview().multipliedBy(1.5)
            make.bottom.equalTo(yearlyTitleLabel.snp.top).offset(-2.0)
        }
    }

    private func applyWidgetViewModel() {
        let tokenSymbol = widgetViewModel?.tokenSymbol ?? ""
        titleLabel.text = R.string.localizable.stakingEstimateEarningTitle_v190(
            tokenSymbol.uppercased(),
            preferredLanguages: locale.rLanguages
        )

        if let viewModel = widgetViewModel?.reward?.value(for: locale) {
            stopLoadingIfNeeded()

            monthlyValueLabel.text = viewModel.monthly
            yearlyValueLabel.text = viewModel.yearly
        } else {
            startLoadingIfNeeded()
        }
    }

    private func applyLocalization() {
        let languages = locale.rLanguages

        monthlyTitleLabel.text = R.string.localizable
            .stakingMonthPeriodTitle(preferredLanguages: languages)

        yearlyTitleLabel.text = R.string.localizable
            .stakingYearPeriodTitle(preferredLanguages: languages)

        applyActionTitle()
    }

    private func applyActionTitle() {
        let title = actionTitle.value(for: locale)
        mainButton.imageWithTitleView?.title = title
        mainButton.invalidateLayout()
    }

    func startLoadingIfNeeded() {
        guard skeletonView == nil else {
            return
        }

        monthlyValueLabel.alpha = 0.0
        yearlyValueLabel.alpha = 0.0

        setupSkeleton()
    }

    func stopLoadingIfNeeded() {
        guard skeletonView != nil else {
            return
        }

        skeletonView?.stopSkrulling()
        skeletonView?.removeFromSuperview()
        skeletonView = nil

        monthlyValueLabel.alpha = 1.0
        yearlyValueLabel.alpha = 1.0
    }

    private func setupSkeleton() {
        let spaceSize = frame.size

        guard spaceSize.width > 0, spaceSize.height > 0 else {
            return
        }

        let builder = Skrull(
            size: spaceSize,
            decorations: [],
            skeletons: createSkeletons(for: spaceSize)
        )

        let currentSkeletonView: SkrullableView?

        if let skeletonView = skeletonView {
            currentSkeletonView = skeletonView
            builder.updateSkeletons(in: skeletonView)
        } else {
            let view = builder
                .fillSkeletonStart(R.color.colorSkeletonStart()!)
                .fillSkeletonEnd(color: R.color.colorSkeletonEnd()!)
                .build()
            view.autoresizingMask = []
            insertSubview(view, aboveSubview: backgroundView)

            skeletonView = view

            view.startSkrulling()

            currentSkeletonView = view
        }

        currentSkeletonView?.frame = CGRect(origin: .zero, size: spaceSize)
    }

    private func createSkeletons(for spaceSize: CGSize) -> [Skeletonable] {
        let bigRowSize = CGSize(width: 72.0, height: 12.0)

        let offsetY = 8.0
        let monthlyOffsetX = monthlyTitleLabel.intrinsicContentSize.width / 2.0 - bigRowSize.width / 2.0
        let yearlyOffsetX = yearlyTitleLabel.intrinsicContentSize.width / 2.0 - bigRowSize.width / 2.0

        return [
            SingleSkeleton.createRow(
                above: monthlyTitleLabel,
                containerView: self,
                spaceSize: spaceSize,
                offset: CGPoint(x: monthlyOffsetX, y: offsetY),
                size: bigRowSize
            ),

            SingleSkeleton.createRow(
                above: yearlyTitleLabel,
                containerView: self,
                spaceSize: spaceSize,
                offset: CGPoint(x: yearlyOffsetX, y: offsetY),
                size: bigRowSize
            )
        ]
    }

    @objc private func actionMainTouchUpInside() {
        delegate?.rewardEstimationDidStartAction(self)
    }

    @objc private func actionInfoTouchUpInside() {
        delegate?.rewardEstimationDidRequestInfo(self)
    }
}

extension RewardEstimationView: SkeletonLoadable {
    func didDisappearSkeleton() {
        skeletonView?.stopSkrulling()
    }

    func didAppearSkeleton() {
        skeletonView?.stopSkrulling()
        skeletonView?.startSkrulling()
    }

    func didUpdateSkeletonLayout() {
        guard skeletonView != nil else {
            return
        }

        setupSkeleton()
    }
}
