import Foundation

protocol SystemAccountValidating {
    func isSystem(accountId: AccountId) -> Bool
}

final class PrefixSystemAccountValidation: SystemAccountValidating {
    let prefixBytes: Data

    init(prefixBytes: Data) {
        self.prefixBytes = prefixBytes
    }

    init(string: String) {
        prefixBytes = string.data(using: .utf8) ?? Data(string.bytes)
    }

    func isSystem(accountId: AccountId) -> Bool {
        accountId.starts(with: prefixBytes)
    }
}

final class CompoundSystemAccountValidation: SystemAccountValidating {
    let validations: [SystemAccountValidating]

    init(validations: [SystemAccountValidating]) {
        self.validations = validations
    }

    func isSystem(accountId: AccountId) -> Bool {
        validations.contains { $0.isSystem(accountId: accountId) }
    }
}

extension CompoundSystemAccountValidation {
    static func substrateAccounts() -> CompoundSystemAccountValidation {
        CompoundSystemAccountValidation(validations: [
            // Pallet-specific technical accounts, e.g. crowdloan-fund, nomination pool,
            PrefixSystemAccountValidation(string: "modl"),
            // Parachain sovereign accounts on relaychain
            PrefixSystemAccountValidation(string: "para"),
            // Relaychain sovereign account on parachains
            PrefixSystemAccountValidation(string: "Parent"),
            // Sibling parachain soveregin accounts
            PrefixSystemAccountValidation(string: "sibl")
        ])
    }
}
