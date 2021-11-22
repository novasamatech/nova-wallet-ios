import Foundation

extension Chain {
    init?(genesisHash: String) {
        switch genesisHash {
        case Chain.polkadot.genesisHash:
            self = .polkadot
        case Chain.kusama.genesisHash:
            self = .kusama
        case Chain.westend.genesisHash:
            self = .westend
        case Chain.rococo.genesisHash:
            self = .rococo
        default:
            return nil
        }
    }

    var genesisHash: String {
        switch self {
        case .polkadot:
            return "91b171bb158e2d3848fa23a9f1c25182fb8e20313b2c1eb49219da7a70ce90c3"
        case .kusama:
            return "b0a8d493285c2df73290dfb7e61f870f17b41801197a149ca93654499ea3dafe"
        case .westend:
            return "e143f23803ac50e8f6f8e62695d1ce9e4e1d68aa36c1cd2cfd15340213f3423e"
        case .rococo:
            return "a84b46a3e602245284bb9a72c4abd58ee979aa7a5d7f8c4dfdddfaaf0665a4ae"
        }
    }

    var erasPerDay: Int {
        switch self {
        case .polkadot:
            return 1
        case .kusama, .westend, .rococo:
            return 4
        }
    }

    func polkascanExtrinsicURL(_ hash: String) -> URL? {
        switch self {
        case .polkadot:
            return URL(string: "https://polkascan.io/polkadot/extrinsic/\(hash)")
        case .kusama:
            return URL(string: "https://polkascan.io/kusama/extrinsic/\(hash)")
        case .westend, .rococo:
            return nil
        }
    }

    func polkascanAddressURL(_ address: String) -> URL? {
        switch self {
        case .polkadot:
            return URL(string: "https://polkascan.io/polkadot/account/\(address)")
        case .kusama:
            return URL(string: "https://polkascan.io/kusama/account/\(address)")
        case .westend, .rococo:
            return nil
        }
    }

    func polkascanEventURL(_ eventId: String) -> URL? {
        switch self {
        case .polkadot:
            return URL(string: "https://polkascan.io/polkadot/event/\(eventId)")
        case .kusama:
            return URL(string: "https://polkascan.io/kusama/event/\(eventId)")
        case .westend, .rococo:
            return nil
        }
    }

    func subscanExtrinsicURL(_ hash: String) -> URL? {
        switch self {
        case .polkadot:
            return URL(string: "https://polkadot.subscan.io/extrinsic/\(hash)")
        case .kusama:
            return URL(string: "https://kusama.subscan.io/extrinsic/\(hash)")
        case .westend:
            return URL(string: "https://westend.subscan.io/extrinsic/\(hash)")
        case .rococo:
            return nil
        }
    }

    func subscanBlockURL(_ block: String) -> URL? {
        switch self {
        case .polkadot:
            return URL(string: "https://polkadot.subscan.io/block/\(block)")
        case .kusama:
            return URL(string: "https://kusama.subscan.io/block/\(block)")
        case .westend:
            return URL(string: "https://westend.subscan.io/block/\(block)")
        case .rococo:
            return nil
        }
    }

    func subscanAddressURL(_ address: String) -> URL? {
        switch self {
        case .polkadot:
            return URL(string: "https://polkadot.subscan.io/account/\(address)")
        case .kusama:
            return URL(string: "https://kusama.subscan.io/account/\(address)")
        case .westend:
            return URL(string: "https://westend.subscan.io/account/\(address)")
        case .rococo:
            return nil
        }
    }

    var analyticsURL: URL? {
        switch self {
        case .polkadot:
            return URL(string: "https://api.subquery.network/sq/ef1rspb/fearless-wallet")
        case .kusama:
            return URL(string: "https://api.subquery.network/sq/ef1rspb/fearless-wallet-ksm")
        case .westend:
            return URL(string: "https://api.subquery.network/sq/ef1rspb/fearless-wallet-westend")
        case .rococo:
            return nil
        }
    }

    func preparedDefaultTypeDefPath() -> String? {
        R.file.runtimeDefaultJson.path()
    }

    func preparedNetworkTypeDefPath() -> String? {
        switch self {
        case .polkadot:
            return R.file.runtimePolkadotJson.path()
        case .kusama:
            return R.file.runtimeKusamaJson.path()
        case .westend:
            return R.file.runtimeWestendJson.path()
        case .rococo:
            return R.file.runtimeRococoJson.path()
        }
    }

    // swiftlint:disable line_length
    func typeDefDefaultFileURL() -> URL? {
        URL(string: "https://raw.githubusercontent.com/valentunn/py-scale-codec/fearless_stable/scalecodec/type_registry/default.json")
    }

    func typeDefNetworkFileURL() -> URL? {
        let base = URL(string: "https://raw.githubusercontent.com/valentunn/py-scale-codec/fearless_stable/scalecodec/type_registry")

        switch self {
        case .westend:
            return base?.appendingPathComponent("westend.json")
        case .kusama:
            return base?.appendingPathComponent("kusama.json")
        case .polkadot:
            return base?.appendingPathComponent("polkadot.json")
        case .rococo:
            return base?.appendingPathComponent("rococo.json")
        }
    }

    func crowdloanDisplayInfoURL() -> URL {
        let base = URL(string: "https://raw.githubusercontent.com/soramitsu/fearless-utils/master/crowdloan")!

        switch self {
        case .westend:
            return base.appendingPathComponent("westend.json")
        case .kusama:
            return base.appendingPathComponent("kusama.json")
        case .polkadot:
            return base.appendingPathComponent("polkadot.json")
        case .rococo:
            return base.appendingPathComponent("rococo.json")
        }
    }
    // swiftlint:enable line_length
}
