import Foundation

struct GiftSecretCreationRequest {
    let seed: Data?
    let ethereumBased: Bool

    init(seed: Data? = nil, ethereumBased: Bool) {
        self.seed = seed
        self.ethereumBased = ethereumBased
    }
}
