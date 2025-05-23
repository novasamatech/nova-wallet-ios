import Foundation

struct WalletMigrationKeypair {
    typealias PublicKey = Data
    typealias PrivateKey = Data

    let publicKey: PublicKey
    let privateKey: PrivateKey
}

enum WalletMigrationAction: String, Equatable {
    case migrate
    case migrateAccepted = "migrate-accepted"
    case migrateComplete = "migrate-complete"
}

enum WalletMigrationQueryKey: String {
    case action
    case key
    case encryptedData = "mnemonic"
    case scheme
    case name
}

enum WalletMigrationDomain: String {
    case origin = "polkadot"
    case destination = "nova"
}

enum WalletMigrationParams {
    static let allowedAppLinkSchemes: Set<String> = ["https", "http"]
    static let encryptionSalt = "ephemeral-salt".data(using: .utf8)!
    static let encryptionAuth = Data([1])
}

enum WalletMigrationMessage: Equatable {
    struct Start: Equatable {
        let originScheme: String
    }

    struct Accepted: Equatable {
        let destinationPublicKey: WalletMigrationKeypair.PublicKey
    }

    struct Complete: Equatable {
        let originPublicKey: WalletMigrationKeypair.PublicKey
        let encryptedData: Data
        let name: String?
    }

    case start(Start)
    case accepted(Accepted)
    case complete(Complete)
}
