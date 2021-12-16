import Foundation
import SubstrateSdk
import SoraFoundation

struct StakingRedeemViewModel {
    let senderAddress: AccountAddress
    let senderIcon: DrawableIcon
    let senderName: String?
    let amount: LocalizableResource<String>
}
