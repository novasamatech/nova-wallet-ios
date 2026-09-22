import Foundation
import Operation_iOS

struct MetaAccountSettingsLocal: Equatable {
    static let defaultAutoAddTokensWithBalance = true

    let metaId: MetaAccountModel.Id
    let autoAddTokensWithBalance: Bool
}

extension MetaAccountSettingsLocal: Identifiable {
    var identifier: String { metaId }
}
