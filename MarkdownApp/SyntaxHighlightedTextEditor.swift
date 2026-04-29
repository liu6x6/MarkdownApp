
import SwiftUI
import Highlightr
import Combine

#if canImport(UIKit)
import UIKit
#endif

#if canImport(AppKit)
import AppKit
#endif

struct SyntaxHighlightedTextEditor: PlatformViewRepresentable {
    @EnvironmentObject var viewModel: AppViewModel
    @Binding var text: String

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    #if os(macOS)
    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        let textView = NSTextView(frame: .zero)

        context.coordinator.scrollView = scrollView
        context.coordinator.setupTextView(textView)

        textView.autoresizingMask = [.width]
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.isEditable = true
        textView.isSelectable = true
        textView.allowsUndo = true
        textView.usesFindBar = true
        textView.isIncrementalSearchingEnabled = true
        
        // Ensure plain text replacement to prevent syntax color overriding
        textView.isRichText = false
        textView.importsGraphics = false
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        
        textView.delegate = context.coordinator

        scrollView.documentView = textView
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        
        scrollView.contentView.postsBoundsChangedNotifications = true
        NotificationCenter.default.addObserver(context.coordinator, selector: #selector(Coordinator.boundsDidChange(_:)), name: NSView.boundsDidChangeNotification, object: scrollView.contentView)

        // Ensure proper sizing
        textView.frame = CGRect(x: 0, y: 0, width: scrollView.contentSize.width, height: scrollView.contentSize.height)
        textView.minSize = CGSize(width: 0.0, height: 0.0)
        textView.maxSize = CGSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        
        return scrollView
    }

    func updateNSView(_ nsView: NSScrollView, context: Context) {
        guard let textView = nsView.documentView as? NSTextView else { return }
        if textView.string != text {
            textView.string = text
        }
        // 检查主题是否已更改
        context.coordinator.updateThemeIfNeeded()
    }
    
    #else
    func makeUIView(context: Context) -> UITextView {
        let highlightr = Highlightr()!
        let storage = CodeAttributedString(highlightr: highlightr)
        storage.language = "markdown"
        
        let layoutManager = NSLayoutManager()
        storage.addLayoutManager(layoutManager)
        
        let textContainer = NSTextContainer(size: .zero)
        layoutManager.addTextContainer(textContainer)
        
        let textView = UITextView(frame: .zero, textContainer: textContainer)
        
        context.coordinator.textView = textView
        context.coordinator.setupTextView(textView, highlightr: highlightr, storage: storage)
        
        textView.isEditable = true
        textView.isSelectable = true
        textView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        textView.delegate = context.coordinator
        
        return textView
    }
    
    func updateUIView(_ uiView: UITextView, context: Context) {
        if uiView.text != text {
            if let storage = context.coordinator.storage {
                storage.replaceCharacters(in: NSRange(location: 0, length: storage.length), with: text)
            } else {
                uiView.text = text
            }
        }
        context.coordinator.updateThemeIfNeeded()
    }
    #endif

    #if os(macOS)
    class Coordinator: NSObject, NSTextViewDelegate {
        var parent: SyntaxHighlightedTextEditor
        var scrollView: NSScrollView?
        private var highlightr: Highlightr?
        private var storage: CodeAttributedString?
        private var cancellables = Set<AnyCancellable>()

        init(_ parent: SyntaxHighlightedTextEditor) {
            self.parent = parent
        }

        func setupTextView(_ textView: NSTextView) {
            highlightr = Highlightr()
            updateTheme()

            storage = CodeAttributedString(highlightr: highlightr!)
            storage!.language = "markdown"

            if let layoutManager = textView.layoutManager {
                storage!.addLayoutManager(layoutManager)
            }
            
            storage?.replaceCharacters(in: NSRange(location: 0, length: storage?.length ?? 0), with: parent.text)
            
            subscribeToScroll()
            subscribeToSearch()
            subscribeToUndoRedo()
        }
        
        func subscribeToSearch() {
            parent.viewModel.searchAction
                .receive(on: RunLoop.main)
                .sink { [weak self] tag in
                    guard let scrollView = self?.scrollView, let textView = scrollView.documentView as? NSTextView else { return }
                    
                    textView.window?.makeFirstResponder(textView)
                    
                    let menuItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
                    menuItem.tag = tag
                    textView.performFindPanelAction(menuItem)
                }
                .store(in: &cancellables)
        }
        
        func subscribeToUndoRedo() {
            parent.viewModel.undoAction
                .receive(on: RunLoop.main)
                .sink { [weak self] _ in
                    guard let scrollView = self?.scrollView, let textView = scrollView.documentView as? NSTextView else { return }
                    textView.undoManager?.undo()
                }
                .store(in: &cancellables)
                
            parent.viewModel.redoAction
                .receive(on: RunLoop.main)
                .sink { [weak self] _ in
                    guard let scrollView = self?.scrollView, let textView = scrollView.documentView as? NSTextView else { return }
                    textView.undoManager?.redo()
                }
                .store(in: &cancellables)
        }
        
        func subscribeToScroll() {
            parent.viewModel.$scrollPercentage
                .receive(on: RunLoop.main)
                .sink { [weak self] percentage in
                    guard let self = self else { return }
                    guard self.parent.viewModel.scrollSource == .preview else { return }
                    guard let scrollView = self.scrollView, let documentView = scrollView.documentView else { return }
                    
                    let maxY = documentView.bounds.height - scrollView.contentView.bounds.height
                    if maxY > 0 {
                        let y = maxY * percentage
                        scrollView.contentView.scroll(to: NSPoint(x: 0, y: y))
                        scrollView.reflectScrolledClipView(scrollView.contentView)
                    }
                }
                .store(in: &cancellables)
        }
        
        @objc func boundsDidChange(_ notification: Notification) {
            guard parent.viewModel.scrollSource != .preview else { return }
            guard let clipView = notification.object as? NSClipView,
                  let documentView = clipView.documentView else { return }
            
            let maxY = documentView.bounds.height - clipView.bounds.height
            if maxY > 0 {
                let percentage = clipView.bounds.origin.y / maxY
                parent.viewModel.scrollSource = .editor
                parent.viewModel.scrollPercentage = percentage
                
                DispatchQueue.main.async {
                    self.parent.viewModel.scrollSource = .none
                }
            }
        }
        
        func updateThemeIfNeeded() {
            updateTheme()
        }
        
        private func updateTheme() {
            let _ = highlightr?.setTheme(to: parent.viewModel.editorTheme)
            
            let fontSize = UserDefaults.standard.double(forKey: "fontSize")
            let finalFontSize = fontSize > 0 ? CGFloat(fontSize) : 14.0
            
            if let theme = highlightr?.theme {
                theme.setCodeFont(NSFont.monospacedSystemFont(ofSize: finalFontSize, weight: .regular))
            }
            
            if let scrollView = self.scrollView, let textView = scrollView.documentView as? NSTextView {
                let useCustomBgColor = UserDefaults.standard.bool(forKey: "useCustomBgColor")
                if useCustomBgColor {
                    let r = UserDefaults.standard.double(forKey: "customBgColorR")
                    let g = UserDefaults.standard.double(forKey: "customBgColorG")
                    let b = UserDefaults.standard.double(forKey: "customBgColorB")
                    textView.backgroundColor = NSColor(deviceRed: CGFloat(r), green: CGFloat(g), blue: CGFloat(b), alpha: 1.0)
                } else if let themeBgColor = highlightr?.theme.themeBackgroundColor {
                    textView.backgroundColor = themeBgColor
                }
                
                let wordWrap = UserDefaults.standard.bool(forKey: "wordWrap")
                if wordWrap {
                    textView.isHorizontallyResizable = false
                    textView.autoresizingMask = [.width]
                    scrollView.hasHorizontalScroller = false
                    textView.textContainer?.widthTracksTextView = true
                    textView.textContainer?.containerSize = NSSize(width: scrollView.contentSize.width, height: CGFloat.greatestFiniteMagnitude)
                } else {
                    textView.isHorizontallyResizable = true
                    textView.autoresizingMask = [.width, .height]
                    scrollView.hasHorizontalScroller = true
                    textView.textContainer?.widthTracksTextView = false
                    textView.textContainer?.containerSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
                }
            }
            
            if let storage = storage {
                storage.language = "markdown" 
            }
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            self.parent.text = textView.string
        }
    }
    #else
    class Coordinator: NSObject, UITextViewDelegate {
        var parent: SyntaxHighlightedTextEditor
        var textView: UITextView?
        private var highlightr: Highlightr?
        var storage: CodeAttributedString?
        private var cancellables = Set<AnyCancellable>()

        init(_ parent: SyntaxHighlightedTextEditor) {
            self.parent = parent
        }

        func setupTextView(_ textView: UITextView, highlightr: Highlightr, storage: CodeAttributedString) {
            self.highlightr = highlightr
            self.storage = storage
            
            updateTheme()

            storage.replaceCharacters(in: NSRange(location: 0, length: storage.length), with: parent.text)
            
            subscribeToScroll()
        }
        
        func subscribeToScroll() {
            parent.viewModel.$scrollPercentage
                .receive(on: RunLoop.main)
                .sink { [weak self] percentage in
                    guard let self = self else { return }
                    guard self.parent.viewModel.scrollSource == .preview else { return }
                    guard let textView = self.textView else { return }
                    
                    let maxY = textView.contentSize.height - textView.bounds.height
                    if maxY > 0 {
                        let y = maxY * percentage
                        textView.setContentOffset(CGPoint(x: 0, y: y), animated: false)
                    }
                }
                .store(in: &cancellables)
        }
        
        func scrollViewDidScroll(_ scrollView: UIScrollView) {
            guard parent.viewModel.scrollSource != .preview else { return }
            
            let maxY = scrollView.contentSize.height - scrollView.bounds.height
            if maxY > 0 {
                let percentage = scrollView.contentOffset.y / maxY
                parent.viewModel.scrollSource = .editor
                parent.viewModel.scrollPercentage = percentage
                
                DispatchQueue.main.async {
                    self.parent.viewModel.scrollSource = .none
                }
            }
        }
        
        func updateThemeIfNeeded() {
            updateTheme()
        }
        
        private func updateTheme() {
            let _ = highlightr?.setTheme(to: parent.viewModel.editorTheme)
            
            let fontSize = UserDefaults.standard.double(forKey: "fontSize")
            let finalFontSize = fontSize > 0 ? CGFloat(fontSize) : 14.0
            
            if let theme = highlightr?.theme {
                theme.setCodeFont(UIFont.monospacedSystemFont(ofSize: finalFontSize, weight: .regular))
            }
            
            if let textView = self.textView {
                let useCustomBgColor = UserDefaults.standard.bool(forKey: "useCustomBgColor")
                if useCustomBgColor {
                    let r = UserDefaults.standard.double(forKey: "customBgColorR")
                    let g = UserDefaults.standard.double(forKey: "customBgColorG")
                    let b = UserDefaults.standard.double(forKey: "customBgColorB")
                    textView.backgroundColor = UIColor(red: CGFloat(r), green: CGFloat(g), blue: CGFloat(b), alpha: 1.0)
                } else if let themeBgColor = highlightr?.theme.themeBackgroundColor {
                    textView.backgroundColor = themeBgColor
                }
            }
            
            if let storage = storage {
                storage.language = "markdown" 
            }
        }

        func textViewDidChange(_ textView: UITextView) {
            self.parent.text = textView.text
        }
    }
    #endif
}
