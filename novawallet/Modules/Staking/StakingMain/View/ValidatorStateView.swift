import Foundation
import Foundation_iOS

class ValidatorStateView: StakingStateView, LocalizableViewProtocol {
    var locale = Locale.current {
        didSet {
            applyLocalization()
            applyViewModel()
        }
    }

    private var localizableViewModel: LocalizableResource<ValidationViewModel>?

    override init(frame: CGRect) {
        super.init(frame: frame)

        applyLocalization()
    }

    func bind(viewModel: LocalizableResource<ValidationViewModel>) {
        localizableViewModel = viewModel

        applyViewModel()
    }

    private func applyLocalization() {
        titleLabel.text = R.string(preferredLanguages: locale.rLanguages).localizable.stakingValidatorSummaryTitle()
    }

    private func applyViewModel() {
        guard let viewModel = localizableViewModel?.value(for: locale) else {
            return
        }

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
}
