import Foundation

extension MythosStakingConfirmPresenter {
    func provideStakeMoreHintsViewModel() {
        let hints: [String] = [
            R.string.localizable.parastkHintRewardBondMore(preferredLanguages: selectedLocale.rLanguages)
        ]

        view?.didReceiveHints(viewModel: hints)
    }
}
