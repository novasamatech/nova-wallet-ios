import Foundation
import Operation_iOS

struct ChainStorageDecodedItem<T: Equatable & Decodable>: Equatable {
    let identifier: String
    let item: T?
}

extension ChainStorageDecodedItem: Identifiable {}
