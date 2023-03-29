protocol Slip44CoinRepositoryProtocol {
    func fetch() -> BaseOperation<Slip44CoinList>
}

final class Slip44CoinRepository: JsonFileRepository<Slip44CoinList>, Slip44CoinRepositoryProtocol {
    let appConfig: ApplicationConfigProtocol

    init(appConfig: ApplicationConfigProtocol) {
        self.appConfig = appConfig
    }

    func fetch() -> BaseOperation<Slip44CoinList> {
        super.fetchOperation(by: appConfig.slip44URL, defaultValue: [])
    }
}
