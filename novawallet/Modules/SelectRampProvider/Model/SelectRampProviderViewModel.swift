import Foundation
import UIKit

extension SelectRampProvider {
    struct ViewModel {
        let titleText: String
        let providers: [ProviderViewModel]
        let footerText: String
    }
}

extension SelectRampProvider.ViewModel {
    struct ProviderViewModel {
        let id: String
        let logo: UIImage
        let descriptionText: String
        let fiatPaymentMethods: [FiatPaymentMethodViewModel]
    }
}
