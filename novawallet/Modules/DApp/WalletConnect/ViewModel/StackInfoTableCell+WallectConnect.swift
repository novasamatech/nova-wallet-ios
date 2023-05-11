import Foundation

extension StackInfoTableCell {
    func bindNetworks(viewModel: DAppNetworksViewModel, locale: Locale) {
        titleLabel.text = R.string.localizable.commonNetworksTitle(
            viewModel.totalNetworks,
            preferredLanguages: locale.rLanguages
        )

        if let networkViewModel = viewModel.network {
            if viewModel.totalNetworks > 1 {
                canSelect = true

                let details = R.string.localizable.commonMoreFormat(
                    networkViewModel.name,
                    "\(viewModel.totalNetworks - 1)",
                    preferredLanguages: locale.rLanguages
                )

                bind(details: details)
            } else {
                canSelect = false

                bind(viewModel: networkViewModel.cellViewModel, cornerRadius: nil)
            }
        } else if viewModel.unsupported > 0 {
            canSelect = true

            let details = R.string.localizable.commonUnsupportedCount(
                format: viewModel.unsupported,
                preferredLanguages: locale.rLanguages
            )

            bind(details: details)
        } else {
            canSelect = false

            let details = R.string.localizable.commonNone(preferredLanguages: locale.rLanguages)

            bind(details: details)
        }
    }
}
