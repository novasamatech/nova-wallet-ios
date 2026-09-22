import Foundation
import Foundation_iOS
import NovaAnalytics

class WalletImportOptionsPresenter: AnalyticsTracking {
    weak var view: WalletImportOptionsViewProtocol?

    let abandonTracker = AnalyticsAbandonTracker {
        AnalyticsEvent.walletCreationAbandoned(lastStep: .other)
    }

    func provideViewModel() {
        fatalError("Must be overriden by subsclass")
    }

    func selectImportMethod(_ method: WalletCreationMethod) {
        trackAnalytics(.walletImportMethodSelected(method: method))

        abandonTracker.markProceeded()
    }

    func selectHardwareWallet(_ option: HardwareWalletOptions) {
        let method: WalletCreationMethod = switch option {
        case .paritySigner:
            .importParitySigner
        case .polkadotVault:
            .importPolkadotVault
        case .ledger, .genericLedger:
            .importLedger
        }

        selectImportMethod(method)
    }
}

extension WalletImportOptionsPresenter: WalletImportOptionsPresenterProtocol {
    func setup() {
        provideViewModel()
    }
}
