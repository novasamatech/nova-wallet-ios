import Foundation

struct GenericLedgerPolkadotSigningParams {
    enum Mode {
        case substrate
        case evm
    }

    let extrinsicProof: Data
    let derivationPath: Data
    let mode: Mode
}
