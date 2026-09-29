import Foundation

struct SubtensorSubnetDetailsInput: Equatable {
    let subnet: SubtensorCatalogueSubnet
    let target: SubtensorStakeTarget
    let validator: SubtensorValidatorDirectoryItem?
}

enum SubtensorSubnetDetailsHost: Equatable {
    case picker
    case pushed
}
