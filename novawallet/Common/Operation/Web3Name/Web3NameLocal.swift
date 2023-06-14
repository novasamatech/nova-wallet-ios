import Foundation

struct Web3NameSearchResponse {
    let owner: AccountId
    let service: [Service]

    struct Service {
        let id: String
        let URLs: [URL]
        let type: String
    }
}
