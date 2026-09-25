import Foundation
import SubstrateSdk

extension SubtensorStakingPallet {
    struct ChainIdentityV2: Decodable, Equatable {
        @BytesCodable var name: Data
        @BytesCodable var url: Data
        @BytesCodable var githubRepo: Data
        @BytesCodable var image: Data
        @BytesCodable var discord: Data
        @BytesCodable var description: Data
        @BytesCodable var additional: Data
    }
}

extension SubtensorStakingPallet.ChainIdentityV2 {
    func toValidatorIdentity() -> SubtensorValidatorIdentity? {
        let identity = SubtensorValidatorIdentity(
            name: Self.text(from: name),
            url: Self.text(from: url),
            githubRepo: Self.text(from: githubRepo),
            image: Self.text(from: image),
            discord: Self.text(from: discord),
            description: Self.text(from: description)
        )

        let fields = [
            identity.name,
            identity.url,
            identity.githubRepo,
            identity.image,
            identity.discord,
            identity.description
        ]

        return fields.contains { $0 != nil } ? identity : nil
    }

    private static func text(from data: Data) -> String? {
        guard let value = String(data: data, encoding: .utf8) else {
            return nil
        }

        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)

        return trimmed.isEmpty ? nil : trimmed
    }
}
