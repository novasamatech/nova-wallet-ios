struct NewWalletCreated: EventProtocol {
    func accept(visitor: EventVisitorProtocol) {
        visitor.processNewWalletCreated(event: self)
    }
}

struct NewWalletImported: EventProtocol {
    func accept(visitor: EventVisitorProtocol) {
        visitor.processWalletImported(event: self)
    }
}

struct WalletRemoved: EventProtocol {
    func accept(visitor: EventVisitorProtocol) {
        visitor.processWalletRemoved(event: self)
    }
}

enum WalletsChangeSource {
    case byUserManually
    case byProxyService
    case byCloudBackup
}

struct WalletsChanged: EventProtocol {
    let source: WalletsChangeSource

    func accept(visitor: EventVisitorProtocol) {
        visitor.processWalletsChanged(event: self)
    }
}
