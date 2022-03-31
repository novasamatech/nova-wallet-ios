import Foundation
import RobinHood

struct PhishingSite: Equatable {
    let host: String
}

extension PhishingSite: Identifiable {
    var identifier: String { host }
}
