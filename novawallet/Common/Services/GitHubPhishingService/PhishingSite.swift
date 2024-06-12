import Foundation
import Operation_iOS

struct PhishingSite: Equatable {
    let host: String
}

extension PhishingSite: Identifiable {
    var identifier: String { host }
}
