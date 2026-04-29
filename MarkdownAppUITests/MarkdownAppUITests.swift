
import XCTest

class MarkdownAppUITests: XCTestCase {

    override func setUpWithError() throws {
        // UI 测试失败时，立即停止，不要继续执行。
        continueAfterFailure = false
    }

    func testAppLaunch() throws {
        // 启动应用
        let app = XCUIApplication()
        app.launch()

        // 断言：“打开”按钮存在于界面上
        // 我们使用 accessibility identifier 来定位元素，这比依赖按钮的文本标签更稳定
        let openButton = app.buttons["openButton"]
        XCTAssertTrue(openButton.exists)
    }
}
