import Foundation

struct PhishingSites: Decodable {
    let deny: Set<String>
}
