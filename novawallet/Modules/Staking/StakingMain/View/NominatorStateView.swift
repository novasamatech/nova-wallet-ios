import Foundation
import Foundation_iOS

class NominatorStateView: StakingStateView, LocalizableViewProtocol {
    private lazy var timer = CountdownTimer()
    private lazy var timeFormatter = TotalTimeFormatter()
    private var localizableViewModel: LocalizableResource<NominationViewModel>?

    var locale = Locale.current {
        didSet {
            applyLocalization()
            applyViewModel()
        }
    }

    deinit {
        timer.stop()
    }

    override init(frame: CGRect) {
        super.init(frame: frame)

        applyLocalization()
        timer.delegate = self
    }

    func bind(viewModel: LocalizableResource<NominationViewModel>) {
        localizableViewModel = viewModel

        timer.stop()
        applyViewModel()
    }

    private func applyLocalization() {
        titleLabel.text = R.string(preferredLanguages: locale.rLanguages).localizable.stakingYourStake()
    }

    private func applyViewModel() {
        guard let viewModel = localizableViewModel?.value(for: locale) else {
            return
        }

        stakeAmountView.valueTop.text = viewModel.totalStakedAmount
        stakeAmountView.valueBottom.text = viewModel.totalStakedPrice

        stakeAmountView.bind(topValue: viewModel.totalStakedAmount, bottomValue: viewModel.totalStakedPrice)

        if case .undefined = viewModel.status {
            toggleStatus(false)
        } else {
            toggleStatus(true)
        }

        var skeletonOptions: StakingStateSkeletonOptions = []

        if viewModel.totalStakedAmount.isEmpty {
            skeletonOptions.insert(.stake)
        }

        switch viewModel.status {
        case .undefined:
            skeletonOptions.insert(.status)
        case .active:
            presentActiveStatus()
        case .inactive:
            presentInactiveStatus()
        case let .waiting(eraCountdown, nominationEra):
            let remainingTime: TimeInterval? = eraCountdown.map { countdown in
                countdown.timeIntervalTillStart(targetEra: nominationEra + 1)
            }
            presentWaitingStatus(remainingTime: remainingTime)
        }

        setupSkeleton(options: skeletonOptions)
    }

    private func toggleStatus(_ shouldShow: Bool) {
        statusView.isHidden = !shouldShow
    }

    private func presentActiveStatus() {
        statusView.glowingView.outerFillColor = R.color.colorTextPositive()!.withAlphaComponent(0.4)
        statusView.glowingView.innerFillColor = R.color.colorTextPositive()!
        statusView.detailsLabel.textColor = R.color.colorTextPositive()!

        statusView.detailsLabel.text = R.string(
            preferredLanguages: locale.rLanguages
        ).localizable.stakingNominatorStatusActive().uppercased()
    }

    private func presentInactiveStatus() {
        statusView.glowingView.outerFillColor = R.color.colorTextNegative()!.withAlphaComponent(0.4)
        statusView.glowingView.innerFillColor = R.color.colorTextNegative()!
        statusView.detailsLabel.textColor = R.color.colorTextNegative()!

        statusView.detailsLabel.text = R.string(
            preferredLanguages: locale.rLanguages
        ).localizable.stakingNominatorStatusInactive().uppercased()
    }

    private func presentWaitingStatus(remainingTime: TimeInterval?) {
        statusView.glowingView.outerFillColor = R.color.colorTextSecondary()!.withAlphaComponent(0.4)
        statusView.glowingView.innerFillColor = R.color.colorTextSecondary()!
        statusView.detailsLabel.textColor = R.color.colorTextSecondary()!

        if let remainingTime = remainingTime {
            let time = (try? timeFormatter.string(from: remainingTime)) ?? ""
            statusView.detailsLabel.text = constructWaitingStatusDetails(for: time)
            timer.start(with: remainingTime, runLoop: .main, mode: .common)
        } else {
            statusView.detailsLabel.text = constructWaitingStatusDetails(for: "-:-:-")
        }
    }

    private func constructWaitingStatusDetails(for timeString: String) -> String {
        if let statics = statics {
            return statics.waitingNextEra(for: timeString, locale: locale).uppercased()
        } else {
            return R.string(
                preferredLanguages: locale.rLanguages
            ).localizable.stakingWaitingNextEraFormat(timeString).uppercased()
        }
    }
}

extension NominatorStateView: CountdownTimerDelegate {
    func didStart(with interval: TimeInterval) {
        let time = (try? timeFormatter.string(from: interval)) ?? ""

        statusView.detailsLabel.text = constructWaitingStatusDetails(for: time)
    }

    func didCountdown(remainedInterval: TimeInterval) {
        let time = (try? timeFormatter.string(from: remainedInterval)) ?? ""

        statusView.detailsLabel.text = constructWaitingStatusDetails(for: time)
    }

    func didStop(with interval: TimeInterval) {
        let time = (try? timeFormatter.string(from: interval)) ?? ""

        statusView.detailsLabel.text = constructWaitingStatusDetails(for: time)
    }
}
