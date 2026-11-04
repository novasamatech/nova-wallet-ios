import Foundation

protocol MevShieldSealing {
    func seal(plaintext: Data, publicKey: Data) throws -> Data
}
