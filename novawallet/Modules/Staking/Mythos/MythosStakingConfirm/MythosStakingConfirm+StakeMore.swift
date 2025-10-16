import Foundation

extension MythosStakingConfirmPresenter {
    func provideStakeMoreHintsViewModel() {
        let hints: [String] = [
            R.string(preferredLanguages: selectedLocale.rLanguages).localizable.parastkHintRewardBondMore()
        ]

        view?.didReceiveHints(viewModel: hints)
    }
}
