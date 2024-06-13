import Foundation
import Operation_iOS

struct ChainStorageItem: Codable, Identifiable, Equatable {
    enum CodingKeys: String, CodingKey {
        case identifier
        case data
    }

    let identifier: String
    let data: Data
}
