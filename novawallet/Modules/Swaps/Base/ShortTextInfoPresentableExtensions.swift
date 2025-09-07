import Foundation_iOS

extension ShortTextInfoPresentable {
    func showFeeInfo(from view: ControllerBackedProtocol?) {
        let title = LocalizableResource {
            R.string(preferredLanguages: $0.rLanguages
            ).localizable.commonNetworkFee()
        }
        let details = LocalizableResource {
            R.string(preferredLanguages: $0.rLanguages
            ).localizable.swapsNetworkFeeDescription()
        }
        showInfo(
            from: view,
            title: title,
            details: details
        )
    }

    func showRateInfo(from view: ControllerBackedProtocol?) {
        let title = LocalizableResource {
            R.string(preferredLanguages: $0.rLanguages
            ).localizable.swapsSetupDetailsRate()
        }
        let details = LocalizableResource {
            R.string(preferredLanguages: $0.rLanguages
            ).localizable.swapsRateDescription()
        }
        showInfo(
            from: view,
            title: title,
            details: details
        )
    }

    func showSlippageInfo(from view: ControllerBackedProtocol?) {
        let title = LocalizableResource {
            R.string(preferredLanguages: $0.rLanguages).localizable.swapsSetupSlippage()
        }
        let details = LocalizableResource {
            R.string(preferredLanguages: $0.rLanguages).localizable.swapsSetupSlippageDescription()
        }
        showInfo(
            from: view,
            title: title,
            details: details
        )
    }

    func showProxyDepositInfo(from view: ControllerBackedProtocol?) {
        let title = LocalizableResource {
            R.string(preferredLanguages: $0.rLanguages).localizable.stakingSetupProxyDeposit()
        }
        let details = LocalizableResource {
            R.string(preferredLanguages: $0.rLanguages).localizable.stakingSetupProxyDepositDetails()
        }
        showInfo(
            from: view,
            title: title,
            details: details
        )
    }
}
