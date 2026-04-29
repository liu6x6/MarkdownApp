
import XCTest
@testable import MarkdownApp

class AppViewModelTests: XCTestCase {

    var viewModel: AppViewModel!
    var testDirectoryURL: URL!

    override func setUpWithError() throws {
        // 在每个测试开始前，创建一个临时的测试目录
        viewModel = AppViewModel()
        let fileManager = FileManager.default
        testDirectoryURL = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try fileManager.createDirectory(at: testDirectoryURL, withIntermediateDirectories: true, attributes: nil)
        
        // 强制 viewModel 使用我们的测试目录
        viewModel.setValue(testDirectoryURL, forKey: "currentDirectoryURL")
    }

    override func tearDownWithError() throws {
        // 在每个测试结束后，清理临时目录
        try FileManager.default.removeItem(at: testDirectoryURL)
        viewModel = nil
        testDirectoryURL = nil
    }

    func testCreateNewFile() throws {
        // 初始状态下，文件列表应为空
        XCTAssertTrue(viewModel.filePaths.isEmpty)

        // 执行创建新文件的操作
        viewModel.createNewFile()

        // 断言：文件列表现在应该包含一个文件
        XCTAssertEqual(viewModel.filePaths.count, 1)
        
        // 断言：创建的文件的确存在于磁盘上
        let createdFilePath = viewModel.filePaths.first!
        XCTAssertTrue(FileManager.default.fileExists(atPath: createdFilePath))
    }
    
    func testDeleteFile() throws {
        // 先创建一个文件
        viewModel.createNewFile()
        let filePath = viewModel.filePaths.first!
        XCTAssertEqual(viewModel.filePaths.count, 1)
        
        // 执行删除操作
        viewModel.deleteFile(at: filePath)
        
        // 断言：文件列表现在应该为空
        XCTAssertTrue(viewModel.filePaths.isEmpty)
        XCTAssertFalse(FileManager.default.fileExists(atPath: filePath))
    }
    
    func testRenameFile() throws {
        // 先创建一个文件
        viewModel.createNewFile()
        let oldPath = viewModel.filePaths.first!
        let oldURL = URL(fileURLWithPath: oldPath)
        let newName = "MyRenamedFile"
        
        // 执行重命名操作
        viewModel.renameFile(from: oldPath, to: newName)
        
        // 断言：文件列表应该仍然只包含一个文件
        XCTAssertEqual(viewModel.filePaths.count, 1)
        
        // 断言：新文件名的文件存在
        let newPath = viewModel.filePaths.first!
        XCTAssertTrue(newPath.contains(newName))
        XCTAssertTrue(FileManager.default.fileExists(atPath: newPath))
        
        // 断言：旧文件名的文件已不存在
        XCTAssertFalse(FileManager.default.fileExists(atPath: oldPath))
    }
}
