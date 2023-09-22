import XCTest
@testable import novawallet

class MarkupParsingOperationFactoryTests: XCTestCase {

    func testMarkupParse() throws {
        let queue = OperationQueue()
        let factory = MarkupParsingOperationFactory(
            markdownParsingOperationFactory: MarkdownParsingOperationFactory(maxSize: nil),
            htmlParsingOperationFactory: HtmlParsingOperationFactory(imageDetectionEnabled: true),
            operationQueue: queue)
        let wrapper = factory.createParseOperation(for: TestData.markupTextInput,
                                                   preferredWidth: 350)
        queue.addOperations(wrapper.allOperations, waitUntilFinished: true)
        let result = try wrapper.targetOperation.extractNoCancellableResultData()
        
        XCTAssertEqual(result?.attributedString.string, TestData.markupTextOutput)
    }
    
    func testMarkdownParse() throws {
        let queue = OperationQueue()
        let factory = MarkupParsingOperationFactory(
            markdownParsingOperationFactory: MarkdownParsingOperationFactory(maxSize: nil),
            htmlParsingOperationFactory: HtmlParsingOperationFactory(imageDetectionEnabled: true),
            operationQueue: queue)
        let wrapper = factory.createParseOperation(for: TestData.markdownTextInput,
                                                   preferredWidth: 350)
        queue.addOperations(wrapper.allOperations, waitUntilFinished: true)
        let result = try wrapper.targetOperation.extractNoCancellableResultData()
        
        XCTAssertEqual(result?.attributedString.string, TestData.markdownTextOutput)
        
    }
    
    func testHtmlMarkdownParse() throws {
        let queue = OperationQueue()
        let factory = MarkupParsingOperationFactory(
            markdownParsingOperationFactory: MarkdownParsingOperationFactory(maxSize: nil),
            htmlParsingOperationFactory: HtmlParsingOperationFactory(imageDetectionEnabled: true),
            operationQueue: queue)
        let wrapper = factory.createParseOperation(for: TestData.htmlWithMarkdownInput,
                                                   preferredWidth: 350)
        queue.addOperations(wrapper.allOperations, waitUntilFinished: true)
        let result = try wrapper.targetOperation.extractNoCancellableResultData()
        
        XCTAssertEqual(result?.attributedString.string, TestData.htmlWithMarkdownOutput)
        
    }

}


enum TestData {
    static var markupTextInput: String = """
Этот текст содержит пример использования **Markdown** форматирования, а также фрагмент HTML кода.
<!DOCTYPE html>
<html>
<head>
    <title>Пример HTML</title>
</head>
<body>
    <h1>Это заголовок в HTML</h1>
    <p>Это абзац текста в HTML.</p>
</body>
</html>
"""
    static var markupTextOutput: String = """
Этот текст содержит пример использования Markdown форматирования, а также фрагмент HTML кода.
Пример HTML
Это заголовок в HTML

Это абзац текста в HTML.

"""
    
    static var markdownTextInput = """
**Header 1**
This is a paragraph of regular text. You can emphasize text with *italics* or **bold**, and also create [links](https://www.example.com).
- List item 1
- List item 2
- List item 3
1. Numbered list item 1
2. Numbered list item 2
3. Numbered list item 3
"""
    
    static var markdownTextOutput = """
Header 1
This is a paragraph of regular text. You can emphasize text with italics or bold, and also create links.
  • List item 1
  • List item 2
  • List item 3
1. Numbered list item 1
2. Numbered list item 2
3. Numbered list item 3
"""
    
    static var htmlWithMarkdownInput = """
**HTML and Markdown Example**
In this example, we will combine both HTML and Markdown to format text.
Here's some **bold** and *italic* text in Markdown, within an HTML `div` element:
<div>
  This is a Markdown paragraph inside an HTML div.
  - You can create lists in Markdown.
  - Like this one.
  - And you can use HTML elements as well.
</div>
"""
    static var htmlWithMarkdownOutput = """
HTML and Markdown Example
In this example, we will combine both HTML and Markdown to format text.
Here's some bold and italic text in Markdown, within an HTML div element:
This is a Markdown paragraph inside an HTML div.
  • You can create lists in Markdown.
  • Like this one.
  m• And you can use HTML elements as well.

"""
}
