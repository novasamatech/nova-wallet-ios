struct SystemProperties: Decodable {
    let isEthereum: Bool
    let ss58Format: UInt16?
    let SS58Prefix: UInt16?
    let tokenDecimals: [UInt16]
    let tokenSymbol: [String]
}
