import UIKit
import SoraFoundation

protocol StakingUnbondingsViewDelegate: AnyObject {
    func stakingUnbondingViewDidCancel(_ view: StakingUnbondingsView)
    func stakingUnbondingViewDidRedeem(_ view: StakingUnbondingsView)
}

final class StakingUnbondingsView: UIView {
    weak var delegate: StakingUnbondingsViewDelegate?

    let backgroundView: TriangularedBlurView = {
        let view = TriangularedBlurView()
        view.sideLength = 12.0
        return view
    }()

    let stackView: UIStackView = {
        let view = UIStackView()
        view.distribution = .fill
        view.axis = .vertical
        view.spacing = 0.0
        return view
    }()

    let titleLabel: UILabel = {
        let label = UILabel()
        label.font = .regularSubheadline
        label.textColor = R.color.colorTransparentText()
        return label
    }()

    let cancelButton: TriangularedButton = {
        let button = TriangularedButton()
        button.applySecondaryDefaultStyle()
        return button
    }()

    let redeemButton: TriangularedButton = {
        let button = TriangularedButton()
        button.applyDefaultStyle()
        return button
    }()

    var locale = Locale.current {
        didSet {
            if oldValue != locale {
                setupLocalization()
                applyViewModels()
            }
        }
    }

    private var countdownTimer: CountdownTimer?
    private lazy var timeFormatter = TotalTimeFormatter()

    private var viewModel: StakingUnbondingViewModel?

    override init(frame: CGRect) {
        super.init(frame: frame)

        setupLayout()
        setupLocalization()
        setupHandlers()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func bind(viewModel: StakingUnbondingViewModel) {
        let oldCount = self.viewModel?.items.count ?? 0
        let newCount = viewModel.items.count

        if newCount > oldCount {
            let newCellsCount = newCount - oldCount
            let newCells: [StakingUnbondingItemView] = (0 ..< newCellsCount).map { _ in
                StakingUnbondingItemView()
            }

            newCells.forEach {
                stackView.addArrangedSubview($0)

                $0.snp.makeConstraints { make in
                    make.height.equalTo(40.0)
                }
            }
        } else if newCount < oldCount {
            let dropCellsCount = oldCount - newCount

            let dropCells = stackView.arrangedSubviews.suffix(dropCellsCount)
            dropCells.forEach { $0.removeFromSuperview() }
        }

        self.viewModel = viewModel

        updateTimer()

        applyViewModels()

        updateRedeemableButtonState()
    }

    private func setupLocalization() {
        let languages = locale.rLanguages

        titleLabel.text = R.string.localizable.walletBalanceUnbonding_v190(preferredLanguages: languages)

        cancelButton.imageWithTitleView?.title = R.string.localizable.commonCancel(
            preferredLanguages: languages
        )

        redeemButton.imageWithTitleView?.title = R.string.localizable.stakingRedeem(
            preferredLanguages: languages
        )
    }

    private func setupLayout() {
        addSubview(backgroundView)
        backgroundView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(UIConstants.horizontalInset)
            make.top.bottom.equalToSuperview()
        }

        addSubview(titleLabel)
        titleLabel.snp.makeConstraints { make in
            make.top.equalToSuperview().inset(16.0)
            make.leading.equalTo(backgroundView).offset(16.0)
            make.trailing.equalTo(backgroundView).offset(-16.0)
        }

        addSubview(stackView)
        stackView.snp.makeConstraints { make in
            make.top.equalTo(titleLabel.snp.bottom).offset(8.0)
            make.leading.equalTo(backgroundView).offset(16.0)
            make.trailing.equalTo(backgroundView).offset(-16.0)
        }

        addSubview(cancelButton)
        cancelButton.snp.makeConstraints { make in
            make.top.equalTo(stackView.snp.bottom).offset(16.0)
            make.leading.equalTo(backgroundView).offset(16.0)
            make.trailing.equalTo(backgroundView.snp.centerX).offset(-8.0)
            make.height.equalTo(44.0)
            make.bottom.equalToSuperview().inset(20.0)
        }

        addSubview(redeemButton)
        redeemButton.snp.makeConstraints { make in
            make.top.equalTo(stackView.snp.bottom).offset(16.0)
            make.leading.equalTo(backgroundView.snp.centerX).offset(8.0)
            make.trailing.equalTo(backgroundView).offset(-16.0)
            make.height.equalTo(44.0)
        }
    }

    private func setupHandlers() {
        cancelButton.addTarget(self, action: #selector(actionCancel), for: .touchUpInside)
        redeemButton.addTarget(self, action: #selector(actionRedeem), for: .touchUpInside)
    }

    @objc private func actionCancel() {
        delegate?.stakingUnbondingViewDidCancel(self)
    }

    @objc private func actionRedeem() {
        delegate?.stakingUnbondingViewDidRedeem(self)
    }

    private func updateRedeemableButtonState() {
        if
            let viewModel = viewModel,
            let activeEra = viewModel.eraCountdown?.activeEra,
            viewModel.items.contains(where: { $0.isRedeemable(from: activeEra) }) {
            redeemButton.applyEnabledStyle()
            redeemButton.isUserInteractionEnabled = true
        } else {
            redeemButton.applyTranslucentDisabledStyle()
            redeemButton.isUserInteractionEnabled = false
        }
    }

    private func applyViewModels() {
        guard let viewModel = viewModel else {
            return
        }

        for (itemViewModel, view) in zip(viewModel.items, stackView.arrangedSubviews) {
            let title = itemViewModel.amount.value(for: locale)

            let timeLeft = createTimeLeft(
                unbondingEra: itemViewModel.unbondingEra,
                eraCountdown: viewModel.eraCountdown
            )

            (view as? StakingUnbondingItemView)?.bind(title: title, timeLeft: timeLeft, locale: locale)
        }
    }

    private func createTimeLeft(unbondingEra: EraIndex, eraCountdown: EraCountdown?) -> String? {
        guard let eraCountdown = eraCountdown else { return "" }

        guard unbondingEra > eraCountdown.activeEra else {
            return nil
        }

        let eraCompletionTime = eraCountdown.timeIntervalTillStart(targetEra: unbondingEra)
        let daysLeft = eraCompletionTime.daysFromSeconds

        if daysLeft == 0 {
            return (try? timeFormatter.string(from: eraCompletionTime)) ?? ""
        } else {
            return R.string.localizable
                .commonDaysLeftFormat(format: daysLeft, preferredLanguages: locale.rLanguages)
        }
    }

    private func updateTimer() {
        if
            let viewModel = viewModel,
            let eraCountdown = viewModel.eraCountdown,
            viewModel.items.contains(where: { $0.isNext(from: eraCountdown.activeEra) }) {
            setupTimer(for: eraCountdown)
        } else {
            clearTimer()
        }
    }

    private func setupTimer(for eraCountdown: EraCountdown) {
        if countdownTimer == nil {
            countdownTimer = CountdownTimer()
            countdownTimer?.delegate = self
        }

        let countdown = eraCountdown.timeIntervalTillNextActiveEraStart()
        countdownTimer?.start(with: countdown, runLoop: .main, mode: .common)
    }

    private func clearTimer() {
        countdownTimer?.delegate = nil
        countdownTimer?.stop()
        countdownTimer = nil
    }
}

extension StakingUnbondingsView: CountdownTimerDelegate {
    func didStart(with _: TimeInterval) {
        applyViewModels()
    }

    func didCountdown(remainedInterval _: TimeInterval) {
        applyViewModels()
    }

    func didStop(with _: TimeInterval) {
        applyViewModels()
    }
}
