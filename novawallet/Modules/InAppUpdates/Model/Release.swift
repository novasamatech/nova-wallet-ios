import Foundation

struct Release: Decodable {
    let version: Version
    let severity: ReleaseSeverity
    let time: Date
}

enum ReleaseSeverity: String, Decodable {
    case normal = "Normal"
    case major = "Major"
    case critical = "Critical"
}
