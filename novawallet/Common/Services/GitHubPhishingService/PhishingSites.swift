import Foundation

struct PhishingSites: Decodable {
    let allow: Set<String>
    let deny: Set<String>

    func blocked() -> Set<String> {
        deny.subtracting(allow)
    }
}
