import Foundation
import Operation_iOS

struct DelegatedAccountSettings: Equatable, Identifiable {
    let identifier: String
    let confirmsOperation: Bool
}
