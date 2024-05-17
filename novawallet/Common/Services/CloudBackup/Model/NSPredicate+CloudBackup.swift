import Foundation

extension NSPredicate {
    static var cloudSyncableWallets: NSPredicate {
        let excludedTypes = [MetaAccountModelType.proxied]

        let excludedTypeValues = excludedTypes.map { NSNumber(value: $0.rawValue) }

        return NSPredicate(
            format: "NOT (%K IN %@)", #keyPath(CDMetaAccount.type),
            excludedTypeValues
        )
    }
}