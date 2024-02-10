import Foundation

enum JsonStringify {
    static func jsonString<T: Encodable>(from model: T) throws -> String {
        let encoder = JSONEncoder()

        let data = try encoder.encode(model)

        guard let string = String(data: data, encoding: .utf8) else {
            throw CommonError.dataCorruption
        }

        return string
    }
}
