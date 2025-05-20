import Foundation

struct WalletMigrationKeypair {
    typealias PublicKey = Data
    typealias PrivateKey = Data

    let publicKey: PublicKey
    let privateKey: PrivateKey
}

enum WalletMigrationAction: String {
    case migrate
    case migrateAccepted = "migrate-accepted"
    case migrateComplete = "migrate-complete"
}

enum WalletMigrationQueryKey: String {
    case key
    case encryptedData = "mnemonic"
    case scheme
    case name
}

enum WalletMigrationMessage {
    struct Start {
        let originScheme: String
    }

    struct Accepted {
        let destinationPublicKey: WalletMigrationKeypair.PublicKey
    }

    struct Complete {
        let originPublicKey: WalletMigrationKeypair.PublicKey
        let encryptedData: Data
        let name: String?
    }

    case start(Start)
    case accepted(Accepted)
    case complete(Complete)
}
