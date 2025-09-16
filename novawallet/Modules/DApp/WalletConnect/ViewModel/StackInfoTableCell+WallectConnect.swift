import Foundation

extension StackInfoTableCell {
    func bindNetworks(viewModel: DAppNetworksViewModel, locale: Locale) {
        titleLabel.text = R.string(
            preferredLanguages: locale.rLanguages
        ).localizable.commonNetworksTitle(viewModel.totalNetworks)

        if let networkViewModel = viewModel.network {
            if viewModel.totalNetworks > 1 {
                canSelect = true

                let details = R.string(
                    preferredLanguages: locale.rLanguages
                ).localizable.commonMoreFormat(
                    networkViewModel.name,
                    "\(viewModel.totalNetworks - 1)"
                )

                bind(details: details)
            } else {
                canSelect = false

                bind(viewModel: networkViewModel.cellViewModel, cornerRadius: nil)
            }
        } else if viewModel.unsupported > 0 {
            canSelect = true

            let details = R.string(
                preferredLanguages: locale.rLanguages
            ).localizable.commonUnsupportedCount(format: viewModel.unsupported)

            bind(details: details)
        } else {
            canSelect = false

            let details = R.string(preferredLanguages: locale.rLanguages).localizable.commonNone()

            bind(details: details)
        }
    }
}
