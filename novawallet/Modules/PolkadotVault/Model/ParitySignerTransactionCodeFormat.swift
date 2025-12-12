import Foundation

enum ParitySignerQRFormat: Equatable {
    case rawBytes
    case extrinsicWithoutProof
    case extrinsicWithProof
}

typealias ParitySignerPreferredQRFormats = [ParitySignerQRFormat]
