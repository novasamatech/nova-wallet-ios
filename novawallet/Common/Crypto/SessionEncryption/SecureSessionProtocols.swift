import Foundation

enum SecureSession {
    typealias PublicKey = Data
    typealias Message = Data
    typealias Cipher = Data
}

protocol SecureSessionCrypting {
    func encrypt(_ message: SecureSession.Message) throws -> SecureSession.Cipher
    func decrypt(_ cipher: SecureSession.Cipher) throws -> SecureSession.Message
}

protocol SecureSessionManaging {
    func startSession() throws -> SecureSession.PublicKey
    func deriveCryptor(peerPubKey: SecureSession.PublicKey) throws -> SecureSessionCrypting
}
