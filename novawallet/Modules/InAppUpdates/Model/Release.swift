import Foundation

struct Release: Decodable, Hashable {
    let version: ReleaseVersion
    let severity: ReleaseSeverity
    let time: Date
}

enum ReleaseSeverity: String, Decodable {
    case normal = "Normal"
    case major = "Major"
    case critical = "Critical"
}
