import Foundation

struct RMRKV2Collection: Decodable {
    let symbol: String?
    let max: UInt64?
    let metadata: String?
    let issuer: String?
}
