import Foundation

extension NSPredicate {
    static var cloudSyncableWallets: NSPredicate {
        let excludedTypes = [
            MetaAccountModelType.proxied,
            MetaAccountModelType.multisig
        ]

        let excludedTypeValues = excludedTypes.map { NSNumber(value: $0.rawValue) }

        return NSPredicate(
            format: "NOT (%K IN %@)", #keyPath(CDMetaAccount.type),
            excludedTypeValues
        )
    }

    static var onlySecretsWallets: NSPredicate {
        NSPredicate(
            format: "%K == %d", #keyPath(CDMetaAccount.type),
            MetaAccountModelType.secrets.rawValue
        )
    }
}
