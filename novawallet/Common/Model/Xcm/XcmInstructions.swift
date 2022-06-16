import Foundation

struct XcmInstructions: Decodable {
    let store: [String: [String]]

    func rawInstructions(from key: String) -> [String]? {
        store[key]
    }
}
