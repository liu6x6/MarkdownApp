
import UniformTypeIdentifiers
import SwiftUI
import Combine
import Markdown

enum ExportAction {
    case pdf
    case html
}

struct AppError: Identifiable {
    let id = UUID()
    var title: String
    var message: String
}

enum ScrollSource {
    case editor
    case preview
    case none
}

struct ImagePreviewData: Identifiable {
    let id = UUID()
    let type: String
    let data: String
}

struct FileNode: Identifiable, Hashable {
    var id: String { url.path }
    let url: URL
    let name: String
    var children: [FileNode]?
    let isSample: Bool
}

class AppViewModel: ObservableObject {
    @Published var markdownText: String = "# Hello, Markdown!\n\n请点击“打开文件夹”以开始。"
    @Published var filePaths: [String] = []
    @Published var documentNodes: [FileNode] = []
    @Published var sampleNodes: [FileNode] = []
    @Published var currentFilePath: String? = nil
    @AppStorage("editorTheme") var editorTheme: String = "xcode"
    @AppStorage("previewTheme") var previewTheme: String = "github"
    @AppStorage("showPreview") var showPreview: Bool = true
    @AppStorage("isReadingMode") var isReadingMode: Bool = false
    @Published var isDirty = false
    @Published var appError: AppError? = nil
    @Published var scrollPercentage: CGFloat = 0.0
    @Published var imagePreview: ImagePreviewData? = nil
    @Published var isDocumentPickerPresented: Bool = false
    
    var scrollSource: ScrollSource = .none
    
    let exportAction = PassthroughSubject<ExportAction, Never>()
    let searchAction = PassthroughSubject<Int, Never>()
    let undoAction = PassthroughSubject<Void, Never>()
    let redoAction = PassthroughSubject<Void, Never>()
    var currentDirectoryURL: URL? = nil
    private var cancellables = Set<AnyCancellable>()

    init() {
        if let url = BookmarkManager.loadUrlFromBookmark() {
                #if os(macOS)
                let hasAccess = url.startAccessingSecurityScopedResource()
                #else
                let hasAccess = true
                #endif

                if hasAccess {
                    self.currentDirectoryURL = url
                    loadFiles(from: url)
                }
            } else {
                #if os(iOS)
                loadSampleFilesIfNeeded()
                #endif
            }

            $markdownText
            .dropFirst()
            .debounce(for: .milliseconds(500), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                self?.isDirty = true
            }
            .store(in: &cancellables)
    }
    
    deinit {
        stopAccessing() 
    }

    func openDirectory() {
        if !promptToSaveChanges() { return }
        stopAccessing()
        
        #if os(macOS)
        let openPanel = NSOpenPanel()
        openPanel.canChooseFiles = true
        openPanel.canChooseDirectories = true
        openPanel.allowsMultipleSelection = false
        openPanel.allowedContentTypes = [.folder, UTType(filenameExtension: "md")!, UTType(filenameExtension: "MD")!]

        if openPanel.runModal() == .OK {
            if let url = openPanel.url {
                let isDirectory = (try? url.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory == true
                let dirUrl = isDirectory ? url : url.deletingLastPathComponent()
                
                BookmarkManager.saveBookmark(for: dirUrl)
                
                let _ = dirUrl.startAccessingSecurityScopedResource()
                
                self.currentDirectoryURL = dirUrl
                loadFiles(from: dirUrl)
                if !isDirectory {
                    self.selectFile(at: url.path)
                }
            }
        }
        #else
        self.isDocumentPickerPresented = true
        #endif
    }
    
    func stopAccessing() {
        currentDirectoryURL?.stopAccessingSecurityScopedResource()
    }
    
    #if os(iOS)
    func handleIOSFileOpen(url: URL) {
        let hasAccess = url.startAccessingSecurityScopedResource()
        defer { if hasAccess { url.stopAccessingSecurityScopedResource() } }

        guard let docsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else { return }
        let destURL = docsDir.appendingPathComponent(url.lastPathComponent)

        if !FileManager.default.fileExists(atPath: destURL.path) {
            do {
                try FileManager.default.copyItem(at: url, to: destURL)
            } catch {
                self.appError = AppError(title: "导入失败", message: error.localizedDescription)
                return
            }
        }

        self.currentDirectoryURL = docsDir
        loadFiles(from: docsDir)
        self.selectFile(at: destURL.path)
    }
    #endif
    func loadFiles(from directoryURL: URL) {
        do {
            let fileURLs = try FileManager.default.contentsOfDirectory(at: directoryURL, includingPropertiesForKeys: nil)
            self.filePaths = fileURLs.filter { $0.pathExtension.lowercased() == "md" }.map { $0.path }.sorted()
        } catch {
            self.appError = AppError(title: "无法加载目录", message: error.localizedDescription)
        }
        scanDocuments()
    }
    
    func scanDocuments() {
        #if os(iOS)
        guard let docsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else { return }
        let samplesURL = docsURL.appendingPathComponent("Samples")
        
        self.sampleNodes = buildTree(for: samplesURL, isSample: true)?.children ?? []
        
        do {
            let urls = try FileManager.default.contentsOfDirectory(at: docsURL, includingPropertiesForKeys: [.isDirectoryKey], options: .skipsHiddenFiles)
            var docNodes: [FileNode] = []
            for url in urls {
                if url.lastPathComponent == "Samples" { continue }
                if let node = buildTree(for: url, isSample: false) {
                    docNodes.append(node)
                }
            }
            self.documentNodes = docNodes.sorted { $0.name < $1.name }
        } catch {
            print("Scan error: \(error)")
        }
        #endif
    }
    
    private func buildTree(for url: URL, isSample: Bool) -> FileNode? {
        var isDir: ObjCBool = false
        FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir)
        
        if isDir.boolValue {
            do {
                let urls = try FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: [.isDirectoryKey], options: .skipsHiddenFiles)
                var children: [FileNode] = []
                for child in urls {
                    if let node = buildTree(for: child, isSample: isSample) {
                        children.append(node)
                    }
                }
                children.sort { $0.name < $1.name }
                return FileNode(url: url, name: url.lastPathComponent, children: children, isSample: isSample)
            } catch {
                return nil
            }
        } else {
            if url.pathExtension.lowercased() == "md" {
                return FileNode(url: url, name: url.lastPathComponent, children: nil, isSample: isSample)
            }
            return nil
        }
    }

    func selectFile(at path: String) {
        if !promptToSaveChanges() { return }
        
        DispatchQueue.global().async {
            do {
                let content = try String(contentsOf: URL(fileURLWithPath: path), encoding: .utf8)
                DispatchQueue.main.async {
                    self.currentFilePath = path
                    self.markdownText = content
                    // small delay to let UI updates settle and prevent dirty flag from being set by immediate textDidChange
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                        self.isDirty = false
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    self.appError = AppError(title: "无法读取文件", message: error.localizedDescription)
                    self.currentFilePath = nil
                }
            }
        }
    }
    
    var canGoPrevious: Bool {
        guard let current = currentFilePath, let index = filePaths.firstIndex(of: current) else { return false }
        return index > 0
    }
    
    var canGoNext: Bool {
        guard let current = currentFilePath, let index = filePaths.firstIndex(of: current) else { return false }
        return index < filePaths.count - 1
    }
    
    func previousFile() {
        guard let current = currentFilePath, let index = filePaths.firstIndex(of: current) else { return }
        if index > 0 {
            selectFile(at: filePaths[index - 1])
        }
    }
    
    func nextFile() {
        guard let current = currentFilePath, let index = filePaths.firstIndex(of: current) else { return }
        if index < filePaths.count - 1 {
            selectFile(at: filePaths[index + 1])
        }
    }
    
    func saveCurrentFile() {
        guard let path = currentFilePath else {
            // 如果没有当前文件路径，则执行另存为
            saveAs()
            return
        }
        do {
            try markdownText.write(to: URL(fileURLWithPath: path), atomically: true, encoding: .utf8)
            isDirty = false
            print("文件已成功保存到 \(path)")
        } catch {
            self.appError = AppError(title: "保存文件失败", message: error.localizedDescription)
        }
    }
    
    func saveAs() {
        #if os(macOS)
        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [UTType(filenameExtension: "md")!]
        savePanel.nameFieldStringValue = "Untitled.md"
        if let dirUrl = currentDirectoryURL {
            savePanel.directoryURL = dirUrl
        }
        
        if savePanel.runModal() == .OK, let url = savePanel.url {
            do {
                try markdownText.write(to: url, atomically: true, encoding: .utf8)
                isDirty = false
                currentFilePath = url.path
                if let dirUrl = currentDirectoryURL {
                    loadFiles(from: dirUrl)
                } else {
                    let dirUrl = url.deletingLastPathComponent()
                    self.currentDirectoryURL = dirUrl
                    loadFiles(from: dirUrl)
                }
            } catch {
                self.appError = AppError(title: "另存为失败", message: error.localizedDescription)
            }
        }
        #else
        self.appError = AppError(title: "提示", message: "iOS 另存为功能尚未实装")
        #endif
    }
    
    func promptToSaveChanges() -> Bool {
        if !isDirty { return true }
        
        #if os(macOS)
        let alert = NSAlert()
        alert.messageText = "您想储存对当前文档的修改吗？"
        alert.informativeText = "如果不储存，您的修改将会丢失。"
        alert.addButton(withTitle: "储存")
        alert.addButton(withTitle: "取消")
        alert.addButton(withTitle: "不储存")
        
        let response = alert.runModal()
        
        switch response {
        case .alertFirstButtonReturn: // 储存
            saveCurrentFile()
            return true
        case .alertSecondButtonReturn: // 取消
            return false
        case .alertThirdButtonReturn: // 不储存
            isDirty = false
            return true
        default:
            return false
        }
        #else
        // In iOS, changes are often auto-saved, but for now we just return true or discard.
        // Or present an alert via SwiftUI. But here it's called from business logic directly.
        saveCurrentFile()
        return true
        #endif
    }
    
    func createNewFile() {
        if !promptToSaveChanges() { return }
        
        var dirURL: URL? = currentDirectoryURL
        #if os(iOS)
        if dirURL == nil || dirURL?.path.contains("/Samples") == true {
            dirURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
            self.currentDirectoryURL = dirURL
        }
        #endif
        
        guard let targetDir = dirURL else { return }
        
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd-HH-mm-ss"
        let name = "Untitled-\(formatter.string(from: Date()))"
        let fileURL = targetDir.appendingPathComponent(name).appendingPathExtension("md")
        do {
            try "# 新建文件".write(to: fileURL, atomically: true, encoding: .utf8)
            loadFiles(from: targetDir)
            selectFile(at: fileURL.path)
        } catch {
            self.appError = AppError(title: "创建文件失败", message: error.localizedDescription)
        }
    }
    
    func deleteFile(at path: String) {
        guard let dirURL = currentDirectoryURL else { return }
        do {
            try FileManager.default.removeItem(atPath: path)
            if currentFilePath == path {
                currentFilePath = nil
                markdownText = ""
                isDirty = false
            }
            loadFiles(from: dirURL)
        } catch {
            self.appError = AppError(title: "删除文件失败", message: error.localizedDescription)
        }
    }
    
    func renameFile(from oldPath: String, to newName: String) {
        guard let dirURL = currentDirectoryURL else { return }
        let oldURL = URL(fileURLWithPath: oldPath)
        let newURL = dirURL.appendingPathComponent(newName).appendingPathExtension("md")
        
        do {
            try FileManager.default.moveItem(at: oldURL, to: newURL)
            if currentFilePath == oldPath {
                currentFilePath = newURL.path
            }
            loadFiles(from: dirURL)
        } catch {
            self.appError = AppError(title: "重命名文件失败", message: error.localizedDescription)
        }
    }
    
    func copyFileToCurrentDirectory(from sourceURL: URL) {
        guard let dirURL = currentDirectoryURL else { return }
        let destinationURL = dirURL.appendingPathComponent(sourceURL.lastPathComponent)
        
        do {
            try FileManager.default.copyItem(at: sourceURL, to: destinationURL)
            loadFiles(from: dirURL)
        } catch {
            self.appError = AppError(title: "复制文件失败", message: error.localizedDescription)
        }
    }
    
    func exportToHTML() {
        let document = Document(parsing: markdownText)
        let htmlContent = document.format()
        
        #if os(macOS)
        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [.html]
        if savePanel.runModal() == .OK {
            if let url = savePanel.url {
                do {
                    try htmlContent.write(to: url, atomically: true, encoding: .utf8)
                } catch {
                    self.appError = AppError(title: "导出 HTML 失败", message: error.localizedDescription)
                }
            }
        }
        #else
        self.appError = AppError(title: "提示", message: "iOS 导出 HTML 功能尚未实装")
        #endif
    }
}
