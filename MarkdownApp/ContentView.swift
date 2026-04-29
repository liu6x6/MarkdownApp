
import SwiftUI
import Markdown

#if os(iOS)
struct DocumentDetailView: View {
    @EnvironmentObject var viewModel: AppViewModel
    let path: String
    @State private var isEditing: Bool = false
    
    var body: some View {
        VStack(spacing: 0) {
            if isEditing {
                EditorView()
            } else {
                WebView(markdown: viewModel.markdownText)
            }
        }
        .navigationTitle(URL(fileURLWithPath: path).lastPathComponent)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .navigationBarTrailing) {
                if isEditing {
                    Button(action: {
                        viewModel.undoAction.send()
                    }) {
                        Image(systemName: "arrow.uturn.backward")
                    }
                    
                    Button(action: {
                        viewModel.redoAction.send()
                    }) {
                        Image(systemName: "arrow.uturn.forward")
                    }
                }
                
                Button(action: {
                    if isEditing {
                        viewModel.saveCurrentFile()
                    }
                    withAnimation {
                        isEditing.toggle()
                    }
                }) {
                    Text(isEditing ? "完成" : "编辑")
                        .fontWeight(.bold)
                }
            }
        }
        .onAppear {
            viewModel.selectFile(at: path)
        }
        .onDisappear {
            if isEditing {
                viewModel.saveCurrentFile()
            }
        }
        .onChange(of: viewModel.isDirty) { isDirty in
            // Auto save on iOS
            if isDirty {
                viewModel.saveCurrentFile()
            }
        }
    }
}

struct ContentView: View {
    @EnvironmentObject var viewModel: AppViewModel

    var body: some View {
        TabView {
            NavigationView {
                FileBrowserView()
                    .navigationTitle("文档")
            }
            .navigationViewStyle(.stack)
            .tabItem {
                Label("文件", systemImage: "folder")
            }
            
            NavigationView {
                SettingsView()
                    .navigationTitle("设置")
            }
            .navigationViewStyle(.stack)
            .tabItem {
                Label("设置", systemImage: "gear")
            }
        }
        .alert(item: $viewModel.appError) { appError in
            Alert(
                title: Text(appError.title),
                message: Text(appError.message),
                dismissButton: .default(Text("好的"))
            )
        }
        .sheet(item: $viewModel.imagePreview) { previewData in
            ImagePreviewView(previewData: previewData)
        }
        .fileImporter(
            isPresented: $viewModel.isDocumentPickerPresented,
            allowedContentTypes: [.plainText],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                if let url = urls.first {
                    viewModel.handleIOSFileOpen(url: url)
                }
            case .failure(let error):
                viewModel.appError = AppError(title: "文件选择错误", message: error.localizedDescription)
            }
        }
    }
}

#else

struct ContentView: View {
    @EnvironmentObject var viewModel: AppViewModel
    @State private var columnVisibility = NavigationSplitViewVisibility.all
    private let themes = ["xcode", "github", "github-dark", "dracula", "nord", "monokai", "atom-one-dark", "vs2015", "solarized-dark", "solarized-light"]
    private let previewThemes = ["github", "modern", "classic", "notion", "dracula"]

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            FileBrowserView()
                .navigationSplitViewColumnWidth(min: 150, ideal: 250, max: 350)
        } detail: {
            HSplitView {
                if viewModel.isReadingMode == false {
                    EditorView()
                        .frame(minWidth: 400, maxWidth: .infinity, maxHeight: .infinity)
                }
                
                if viewModel.showPreview || viewModel.isReadingMode {
                    WebView(markdown: viewModel.markdownText)
                        .frame(minWidth: 200, maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
        .frame(minWidth: 800, minHeight: 600)
        .toolbar {
            ToolbarItemGroup(placement: .navigation) {
                Button(action: {
                    viewModel.previousFile()
                }) {
                    Label("上一个", systemImage: "chevron.left")
                }
                .disabled(!viewModel.canGoPrevious)
                
                Button(action: {
                    viewModel.nextFile()
                }) {
                    Label("下一个", systemImage: "chevron.right")
                }
                .disabled(!viewModel.canGoNext)
            }
            
            ToolbarItemGroup(placement: .primaryAction) {
                Button(action: {
                    viewModel.createNewFile()
                }) {
                    Label("新建文档", systemImage: "square.and.pencil")
                }
                
                Button(action: {
                    viewModel.openDirectory()
                }) {
                    Label("打开...", systemImage: "folder")
                }
                
                Divider()
                
                Button(action: {
                    viewModel.undoAction.send()
                }) {
                    Label("撤销", systemImage: "arrow.uturn.backward")
                }
                
                Button(action: {
                    viewModel.redoAction.send()
                }) {
                    Label("重做", systemImage: "arrow.uturn.forward")
                }
                
                Divider()
                
                Button(action: {
                    viewModel.searchAction.send(1) // NSTextFinder.Action.showFindInterface
                }) {
                    Label("搜索", systemImage: "magnifyingglass")
                }
                
                Button(action: {
                    viewModel.searchAction.send(12) // NSTextFinder.Action.showReplaceInterface
                }) {
                    Label("替换", systemImage: "arrow.2.squarepath")
                }
                
                Divider()
                
                Button(action: {
                    viewModel.saveCurrentFile()
                }) {
                    Label("保存", systemImage: "square.and.arrow.down")
                }
            }
            
            ToolbarItem {
                Menu {
                    Button("导出为 HTML") {
                        viewModel.exportToHTML()
                    }
                    Button("导出为 PDF") {
                        viewModel.exportAction.send(.pdf)
                    }
                } label: {
                    Label("导出", systemImage: "square.and.arrow.up")
                }
            }
            
            ToolbarItem {
                Menu {
                    Picker("编辑器主题", selection: $viewModel.editorTheme) {
                        ForEach(themes, id: \.self) { theme in
                            Text(theme).tag(theme)
                        }
                    }
                } label: {
                    Label("编辑器主题", systemImage: "macwindow.badge.plus")
                }
            }
            
            ToolbarItem {
                Menu {
                    Picker("预览主题", selection: $viewModel.previewTheme) {
                        ForEach(previewThemes, id: \.self) { theme in
                            Text(theme.capitalized).tag(theme)
                        }
                    }
                } label: {
                    Label("预览主题", systemImage: "doc.richtext")
                }
            }
            
            ToolbarItem {
                Button(action: {
                    withAnimation {
                        viewModel.showPreview.toggle()
                        viewModel.isReadingMode = false
                    }
                }) {
                    Label(viewModel.showPreview ? "隐藏预览" : "显示预览", systemImage: viewModel.showPreview ? "eye.slash" : "eye")
                }
            }
            
            ToolbarItem {
                Button(action: {
                    withAnimation {
                        viewModel.isReadingMode.toggle()
                        viewModel.showPreview = false
                    }
                }) {
                    Label(viewModel.isReadingMode ? "关闭阅读模式" : "阅读模式", systemImage: viewModel.isReadingMode ? "book.closed" : "book" )
                }
            }
        }
        .alert(item: $viewModel.appError) { appError in
            Alert(
                title: Text(appError.title),
                message: Text(appError.message),
                dismissButton: .default(Text("好的"))
            )
        }
        .sheet(item: $viewModel.imagePreview) { previewData in
            ImagePreviewView(previewData: previewData)
        }
    }
}
#endif

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .environmentObject(AppViewModel())
    }
}
