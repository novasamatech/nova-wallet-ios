import Foundation
import Foundation_iOS

extension ShortTextInfoPresentable {
    func showFeeInfo(from view: ControllerBackedProtocol?) {
        let title = LocalizableResource {
            R.string(preferredLanguages: $0.rLanguages).localizable.commonNetworkFee()
        }
        let details = LocalizableResource {
            R.string(preferredLanguages: $0.rLanguages).localizable.swapsNetworkFeeDescription()
        }
        showInfo(
            from: view,
            title: title,
            details: details
        )
    }

    func showRateInfo(from view: ControllerBackedProtocol?, commissionRate: BigRational?) {
        let title = LocalizableResource {
            R.string(preferredLanguages: $0.rLanguages).localizable.swapsSetupDetailsRate()
        }
        let details = LocalizableResource { locale in
            guard let commissionRate else {
                return R.string(preferredLanguages: locale.rLanguages).localizable.swapsRateDescription()
            }

            let percent = SwapBaseViewModelFactory.commissionPercent(
                rate: commissionRate,
                percentFormatter: NumberFormatter.percentSingle.localizableResource(),
                locale: locale
            )

            return R.string(
                preferredLanguages: locale.rLanguages
            ).localizable.swapsRateIncludesCommissionDescription(percent)
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
