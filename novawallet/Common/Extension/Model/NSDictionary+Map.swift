import Foundation

extension NSDictionary {
    func map<T: Decodable>(to type: T.Type) throws -> T {
        let data = try JSONSerialization.data(withJSONObject: self, options: [])
        return try JSONDecoder().decode(type, from: data)
    }
}
