import MarkdownView
import CoreGraphics

extension MarkdownView {
    func loadFull(markdownText: String) {
        load(
            markdown: markdownText,
            css: css(coloredLink: R.color.colorNovaBlue()),
            plugins: plugins()
        )
    }

    func loadLimitedText(
        markdownText: String,
        maxLinesCount: Int
    ) {
        let css = [
            css(coloredLink: R.color.colorNovaBlue()),
            css(maxLinesCount: maxLinesCount)
        ].compactMap { $0 }.joined(separator: "\n")

        return load(
            markdown: markdownText,
            enableImage: false,
            css: css,
            plugins: plugins()
        )
    }

    private func plugins() -> [String]? {
        [
            URL(string: "https://cdnjs.cloudflare.com/ajax/libs/markdown-it-footnote/3.0.3/markdown-it-footnote.js"),
            URL(string: "https://cdn.jsdelivr.net/npm/markdown-it-sub@1.0.0/index.min.js"),
            URL(string: "https://cdn.jsdelivr.net/npm/markdown-it-sup@1.0.0/index.min.js"),
            URL(string: "https://cdn.jsdelivr.net/npm/markdown-it-ins@3.0.1/dist/markdown-it-ins.min.js"),
            URL(string: "https://cdn.jsdelivr.net/npm/markdown-it-mark@3.0.1/dist/markdown-it-mark.min.js"),
            URL(string: "https://cdn.jsdelivr.net/npm/markdown-it-container@3.0.0/dist/markdown-it-container.min.js"),
            URL(string: "https://cdn.jsdelivr.net/npm/markdown-it-deflist@2.1.0/dist/markdown-it-deflist.min.js")
        ].compactMap { $0 }
            .compactMap { try? String(contentsOf: $0, encoding: .utf8) }
    }

    private func css(coloredLink color: UIColor?) -> String? {
        guard let color = color else {
            return nil
        }
        return "a { color: \(color); }"
    }

    private func css(maxLinesCount: Int) -> String {
        """
                p {
                      -webkit-line-clamp: \(maxLinesCount);
                      display: -webkit-box;
                      -webkit-box-orient: vertical;
                      overflow: hidden;
                }
        """
    }
}
