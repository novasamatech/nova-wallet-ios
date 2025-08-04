import Foundation

protocol AppAttestClientHashing {
    func hash(challenge: Data, data: Data?) throws -> Data
}

final class AppAttestClientHashCalculator: AppAttestClientHashing {
    func hash(challenge: Data, data: Data?) throws -> Data {
        if let data {
            (challenge + data.sha256()).sha256()
        } else {
            challenge.sha256()
        }
    }
}
