import Foundation

extension String {
    private static let htmlSpecificTags: Set<String> = [
        "</p>", "</div>", "</body>", "</br>", "</h1>", "</h2>", "</h3>", "</h4>", "</h5>", "</h6>",
        "</header>", "</ul>"
    ]

    func isHtml() -> Bool {
        Self.htmlSpecificTags.contains { tag in
            range(of: tag) != nil
        }
    }
}
