import UIKit
import RobinHood

enum DAppBrowserInteractorError: Error {
    case scriptFileMissing
    case invalidUrl
    case unexpectedMessageType
}

final class DAppBrowserInteractor {
    static let subscriptionName = "_nova_"

    weak var presenter: DAppBrowserInteractorOutputProtocol!

    let userInput: String
    let wallet: MetaAccountModel
    let operationQueue: OperationQueue
    let logger: LoggerProtocol?

    init(
        userInput: String,
        wallet: MetaAccountModel,
        operationQueue: OperationQueue,
        logger: LoggerProtocol? = nil
    ) {
        self.userInput = userInput
        self.wallet = wallet
        self.operationQueue = operationQueue
        self.logger = logger
    }

    private func createBridgeScriptOperation() -> BaseOperation<DAppBrowserScript> {
        ClosureOperation<DAppBrowserScript> {
            guard let jsUrl = Bundle.main.url(forResource: "nova-min", withExtension: "js") else {
                throw DAppBrowserInteractorError.scriptFileMissing
            }

            let content = try String(contentsOf: jsUrl)

            return DAppBrowserScript(content: content, insertionPoint: .atDocStart)
        }
    }

    private func createSubscriptionScript() -> DAppBrowserScript {
        let content =
            """
            window.addEventListener("message", ({ data, source }) => {
              // only allow messages from our window, by the loader
              if (source !== window) {
                return;
              }

              if (data.origin === "dapp-request") {
                window.webkit.messageHandlers.\(Self.subscriptionName).postMessage(data);
              }
            });
            """

        let script = DAppBrowserScript(content: content, insertionPoint: .atDocEnd)
        return script
    }

    func provideModel() {
        let maybeUrl: URL? = {
            if NSPredicate.urlPredicate.evaluate(with: userInput), let inputUrl = URL(string: userInput) {
                return inputUrl
            } else {
                let querySet = CharacterSet.urlQueryAllowed
                guard let searchQuery = userInput.addingPercentEncoding(withAllowedCharacters: querySet) else {
                    return nil
                }

                return URL(string: "https://www.google.com/search?q=\(searchQuery)")
            }
        }()

        guard let url = maybeUrl else {
            presenter.didReceive(error: DAppBrowserInteractorError.invalidUrl)
            return
        }

        let bridgeOperation = createBridgeScriptOperation()
        let subscriptionScript = createSubscriptionScript()

        bridgeOperation.completionBlock = { [weak self] in
            DispatchQueue.main.async {
                do {
                    let bridgeScript = try bridgeOperation.extractNoCancellableResultData()

                    let model = DAppBrowserModel(
                        url: url,
                        subscriptionName: Self.subscriptionName,
                        scripts: [bridgeScript, subscriptionScript]
                    )

                    self?.presenter.didReceiveDApp(model: model)
                } catch {
                    self?.presenter.didReceive(error: error)
                }
            }
        }

        operationQueue.addOperation(bridgeOperation)
    }
}

extension DAppBrowserInteractor: DAppBrowserInteractorInputProtocol {
    func setup() {
        provideModel()
    }

    func process(message: Any) {
        guard let dict = message as? NSDictionary else {
            presenter.didReceive(error: DAppBrowserInteractorError.unexpectedMessageType)
            return
        }

        do {
            let parsedMessage = try dict.map(to: PolkadotExtensionMessage.self)
            logger?.error("Did receive message: \(parsedMessage)")
        } catch {
            presenter.didReceive(error: error)
        }
    }
}
