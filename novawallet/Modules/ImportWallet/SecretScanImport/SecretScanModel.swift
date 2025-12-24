import Foundation

enum SecretScanModel {
    case seed(Data)
    case keypair(publicKey: Data, secretKey: Data)
}
