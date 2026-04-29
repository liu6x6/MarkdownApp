
import SwiftUI

#if os(macOS)
import AppKit
#else
import UIKit
#endif

@main
struct MarkdownApp: App {
    #if os(macOS)
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    #else
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    #endif
    
    var body: some Scene {
        // 使用自定义的 Scene 来处理窗口状态
        MainScene()
            .environmentObject(appDelegate.appViewModel)
            
        #if os(macOS)
        Settings {
            SettingsView()
        }
        #endif
    }
}

struct MainScene: Scene {
    @EnvironmentObject var viewModel: AppViewModel
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                #if os(macOS)
                .onReceive(viewModel.$isDirty) { isDirty in
                    // 更新窗口的文档编辑状态
                    NSApp.keyWindow?.isDocumentEdited = isDirty
                }
                #endif
        }
        #if os(macOS)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("新建文档") {
                    viewModel.createNewFile()
                }
                .keyboardShortcut("n", modifiers: .command)
                
                Button("打开文件或文件夹...") {
                    viewModel.openDirectory()
                }
                .keyboardShortcut("o", modifiers: .command)
            }
            CommandGroup(replacing: .saveItem) {
                Button("保存") {
                    viewModel.saveCurrentFile()
                }
                .keyboardShortcut("s", modifiers: .command)

                Button("另存为...") {
                    viewModel.saveAs()
                }
                .keyboardShortcut("s", modifiers: [.command, .shift])

                Divider()

                Button("导出为 HTML...") {
                    viewModel.exportToHTML()
                }

                Button("导出为 PDF...") {
                    viewModel.exportAction.send(.pdf)
                }
            }

            CommandGroup(replacing: .undoRedo) {
                Button("撤销") {
                    viewModel.undoAction.send()
                }
                .keyboardShortcut("z", modifiers: .command)

                Button("重做") {
                    viewModel.redoAction.send()
                }
                .keyboardShortcut("z", modifiers: [.command, .shift])
            }

            CommandMenu("编辑") {
                Button("搜索") {
                    viewModel.searchAction.send(1)
                }
                .keyboardShortcut("f", modifiers: .command)

                Button("替换") {
                    viewModel.searchAction.send(12)
                }
                .keyboardShortcut("r", modifiers: .command)
            }

            CommandMenu("导航") {
                Button("上一个文件") {
                    viewModel.previousFile()
                }
                .keyboardShortcut("[", modifiers: .command)
                .disabled(!viewModel.canGoPrevious)

                Button("下一个文件") {
                    viewModel.nextFile()
                }
                .keyboardShortcut("]", modifiers: .command)
                .disabled(!viewModel.canGoNext)
            }

            CommandGroup(replacing: .windowList) {
                Button("关闭窗口") {
                    if viewModel.promptToSaveChanges() {
                        NSApp.keyWindow?.close()
                    }
                }
                .keyboardShortcut("w", modifiers: .command)
            }
        }
        #endif
    }
}

#if os(macOS)
class AppDelegate: NSObject, NSApplicationDelegate {
    let appViewModel = AppViewModel()

    func applicationWillTerminate(_ aNotification: Notification) {
        // 在应用退出前，停止访问书签范围的资源
        appViewModel.stopAccessing()
    }
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }
    
    func application(_ application: NSApplication, open urls: [URL]) {
        if let url = urls.first {
            // 如果打开的是文件，把它所在的目录作为工作区，然后选中它
            let isDirectory = (try? url.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory == true
            let dirUrl = isDirectory ? url : url.deletingLastPathComponent()
            
            BookmarkManager.saveBookmark(for: dirUrl)
            let _ = dirUrl.startAccessingSecurityScopedResource()
            appViewModel.currentDirectoryURL = dirUrl
            appViewModel.loadFiles(from: dirUrl)
            
            if !isDirectory {
                appViewModel.selectFile(at: url.path)
            }
        }
    }
    
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        if appViewModel.promptToSaveChanges() {
            return .terminateNow
        } else {
            return .terminateCancel
        }
    }
}
#else
class AppDelegate: NSObject, UIApplicationDelegate {
    let appViewModel = AppViewModel()
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        return true
    }
    
    func applicationWillTerminate(_ application: UIApplication) {
        appViewModel.stopAccessing()
    }
}
#endif
