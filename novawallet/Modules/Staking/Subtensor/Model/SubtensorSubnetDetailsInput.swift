import Foundation

struct SubtensorSubnetDetailsInput: Equatable {
    let subnet: SubtensorCatalogueSubnet
    let target: SubtensorStakeTarget
    let validator: SubtensorValidatorDirectoryItem?
    var recommendedHotkey: AccountId?
}

enum SubtensorSubnetDetailsHost: Equatable {
    case picker
    case pushed
}
