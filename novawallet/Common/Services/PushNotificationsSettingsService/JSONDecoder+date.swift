import Foundation

extension JSONDecoder.DateDecodingStrategy {
    static func firestore() -> JSONDecoder.DateDecodingStrategy {
        .formatted(
            DateFormatter.with(format: "yyyy-MM-dd'T'HH:mm:ss.SSS'Z'")
        )
    }
}
