import Foundation

struct SupportedLedgerApp {
    enum AppType {
        case substrate
        case ethereum
    }

    let chainId: ChainModel.Id
    let coin: UInt32
    let cla: UInt8
    let type: AppType
}

extension SupportedLedgerApp {
    static func all() -> [SupportedLedgerApp] {
        [
            SupportedLedgerApp(chainId: KnowChainId.polkadot, coin: 354, cla: 0x90, type: .substrate),
            SupportedLedgerApp(chainId: KnowChainId.kusama, coin: 434, cla: 0x99, type: .substrate),
            SupportedLedgerApp(chainId: KnowChainId.statemint, coin: 354, cla: 0x96, type: .substrate),
            SupportedLedgerApp(chainId: KnowChainId.statemine, coin: 434, cla: 0x97, type: .substrate),
            SupportedLedgerApp(chainId: KnowChainId.edgeware, coin: 523, cla: 0x94, type: .substrate)
        ]
    }

    static func substrate() -> [SupportedLedgerApp] {
        all().filter { $0.type == .substrate }
    }
}
