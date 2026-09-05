import Foundation

extension NSSortDescriptor {
    static var accountsByOrder: NSSortDescriptor {
        NSSortDescriptor(key: #keyPath(CDMetaAccount.order), ascending: true)
    }

    static var accountsBySelection: NSSortDescriptor {
        NSSortDescriptor(key: #keyPath(CDMetaAccount.isSelected), ascending: false)
    }

    static var contactsByTime: NSSortDescriptor {
        NSSortDescriptor(key: #keyPath(CDContactItem.updatedAt), ascending: false)
    }

    static var chainsByAddressPrefix: NSSortDescriptor {
        NSSortDescriptor(key: #keyPath(CDChain.addressPrefix), ascending: true)
    }

    static var chainsByOrder: NSSortDescriptor {
        NSSortDescriptor(key: #keyPath(CDChain.order), ascending: true)
    }

    static var nftsByCreationDesc: NSSortDescriptor {
        NSSortDescriptor(key: #keyPath(CDNft.createdAt), ascending: false)
    }
}
