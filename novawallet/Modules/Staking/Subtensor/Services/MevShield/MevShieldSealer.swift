import Foundation
import CryptoSwift
import MLKEMNative
import SubstrateSdk

protocol MevShieldRandomnessSourceProtocol {
    func randomBytes(count: Int) throws -> Data
}

struct MevShieldSecureRandomness: MevShieldRandomnessSourceProtocol {
    func randomBytes(count: Int) throws -> Data {
        guard let bytes = Data.random(of: count) else {
            throw MevShieldSealerError.randomnessUnavailable
        }

        return bytes
    }
}

enum MevShieldSealerError: Error {
    case randomnessUnavailable
    case unexpectedKemCiphertextLength(Int)
    case ciphertextTooLong(Int)
}

final class MevShieldSealer {
    let randomness: MevShieldRandomnessSourceProtocol

    init(randomness: MevShieldRandomnessSourceProtocol = MevShieldSecureRandomness()) {
        self.randomness = randomness
    }
}

extension MevShieldSealer: MevShieldSealing {
    func seal(plaintext: Data, publicKey: Data) throws -> Data {
        let kemRandomness = try randomness.randomBytes(count: MLKEMNative768.randomnessLength)
        let encapsulation = try MLKEMNative768.encapsulate(publicKey: publicKey, randomness: kemRandomness)

        guard encapsulation.ciphertext.count == MevShieldPallet.kemCiphertextLength else {
            throw MevShieldSealerError.unexpectedKemCiphertextLength(encapsulation.ciphertext.count)
        }

        let nonce = try randomness.randomBytes(count: MevShieldPallet.aeadNonceLength)

        let sealed = try AEADXChaCha20Poly1305.encrypt(
            Array(plaintext),
            key: Array(encapsulation.sharedSecret),
            iv: Array(nonce),
            authenticationHeader: []
        )

        let kemLength = Data(UInt16(MevShieldPallet.kemCiphertextLength).littleEndianBytes)

        let payload = publicKey.twox128() + kemLength + encapsulation.ciphertext + nonce +
            Data(sealed.cipherText) + Data(sealed.authenticationTag)

        guard payload.count <= MevShieldPallet.maxCiphertextLength else {
            throw MevShieldSealerError.ciphertextTooLong(payload.count)
        }

        return payload
    }
}
