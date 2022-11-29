import Foundation

struct EtherscanHistoryElement: Decodable {
    let blockNumber: String
    let timeStamp: String
    let hash: String
    let from: String
    let to: String
    let value: String
    let gasPrice: String
    let gasUsed: String
}
