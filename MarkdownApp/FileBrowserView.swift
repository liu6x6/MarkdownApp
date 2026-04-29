
import SwiftUI

struct FileBrowserView: View {
    @EnvironmentObject var viewModel: AppViewModel
    @State private var renamingPath: String? = nil
    @State private var newName: String = ""
    
    @State private var isSamplesExpanded: Bool = true
    @State private var isDocumentsExpanded: Bool = true

    var sampleFiles: [String] {
        viewModel.filePaths.filter { $0.contains("/Sample/") }
    }
    
    var documentFiles: [String] {
        viewModel.filePaths.filter { !$0.contains("/Sample/") }
    }

    var body: some View {
        VStack(spacing: 0) {
            #if os(macOS)
            HStack {
                Button(action: {
                    viewModel.openDirectory()
                }) {
                    Label("打开", systemImage: "folder")
                }
                .accessibilityIdentifier("openButton")
                
                Button(action: {
                    viewModel.createNewFile()
                }) {
                    Label("新建文件", systemImage: "doc.badge.plus")
                }
            }
            .padding()
            #endif

            List(selection: $viewModel.currentFilePath) {
                if !sampleFiles.isEmpty {
                    DisclosureGroup(isExpanded: $isSamplesExpanded) {
                        ForEach(sampleFiles, id: \.self) { path in
                            fileRow(for: path)
                        }
                    } label: {
                        Label("示例 (Samples)", systemImage: "book.pages")
                            .font(.headline)
                    }
                }
                
                if !documentFiles.isEmpty || sampleFiles.isEmpty {
                    DisclosureGroup(isExpanded: $isDocumentsExpanded) {
                        ForEach(documentFiles, id: \.self) { path in
                            fileRow(for: path)
                        }
                    } label: {
                        Label("文档 (Documents)", systemImage: "doc.text")
                            .font(.headline)
                    }
                }
            }
            .listStyle(.sidebar)
            .onDrop(of: [.fileURL], isTargeted: nil) { providers in
                for provider in providers {
                    _ = provider.loadObject(ofClass: URL.self) { url, error in
                        if let url = url {
                            DispatchQueue.main.async {
                                viewModel.copyFileToCurrentDirectory(from: url)
                            }
                        }
                    }
                }
                return true
            }
        }
        .frame(minWidth: 200, idealWidth: 250, maxWidth: .infinity)
        #if os(iOS)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack {
                    Button(action: {
                        viewModel.openDirectory()
                    }) {
                        Image(systemName: "folder")
                    }
                    Button(action: {
                        viewModel.createNewFile()
                    }) {
                        Image(systemName: "square.and.pencil")
                    }
                }
            }
        }
        .sheet(isPresented: $showingRenameSheet) {
            if let path = pathToRename {
                RenameFileView(originalPath: path, newName: newName) { old, new in
                    viewModel.renameFile(from: old, to: new)
                }
            }
        }
        #endif
    }
    
    @State private var showingRenameSheet = false
    @State private var pathToRename: String? = nil
    
    // ...

    @ViewBuilder
    private func fileRow(for path: String) -> some View {
        #if os(macOS)
        if renamingPath == path {
            TextField("新文件名", text: $newName, onCommit: {
                viewModel.renameFile(from: path, to: newName)
                renamingPath = nil
                newName = ""
            })
        } else {
            Label(URL(fileURLWithPath: path).lastPathComponent, systemImage: "doc.plaintext")
                .onTapGesture {
                    viewModel.selectFile(at: path)
                }
                .contextMenu {
                    Button("重命名") {
                        renamingPath = path
                        newName = URL(fileURLWithPath: path).deletingPathExtension().lastPathComponent
                    }
                    Button("删除", role: .destructive) {
                        viewModel.deleteFile(at: path)
                    }
                }
        }
        #else
        NavigationLink(destination: DocumentDetailView(path: path)) {
            Label(URL(fileURLWithPath: path).lastPathComponent, systemImage: "doc.plaintext")
        }
        .contextMenu {
            Button("重命名") {
                pathToRename = path
                newName = URL(fileURLWithPath: path).deletingPathExtension().lastPathComponent
                showingRenameSheet = true
            }
            if !path.contains("/Sample/") {
                Button("删除", role: .destructive) {
                    viewModel.deleteFile(at: path)
                }
            }
        }
        #endif
    }
}

#if os(iOS)
struct RenameFileView: View {
    @Environment(\.presentationMode) var presentationMode
    let originalPath: String
    @State var newName: String
    let onRename: (String, String) -> Void
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("输入新文件名")) {
                    TextField("文件名", text: $newName)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                }
            }
            .navigationTitle("重命名文件")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        onRename(originalPath, newName)
                        presentationMode.wrappedValue.dismiss()
                    }
                    .disabled(newName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
}
#endif
