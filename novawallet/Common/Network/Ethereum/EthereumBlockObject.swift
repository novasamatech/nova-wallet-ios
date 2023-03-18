import Foundation

struct EthereumBlockObject: Decodable {
    struct Transaction: Decodable {
        let hash: String
        let from: String
        let input: String?
        let to: String?
    }

    let transactions: [Transaction]
}
