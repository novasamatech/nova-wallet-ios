import Foundation

enum NftType: UInt16, Equatable {
    case uniques
    case rmrkV1 // this type was deprecated but we keep him for cache purpose
    case rmrkV2
    case pdc20
}
