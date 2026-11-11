
import SwiftUI
import Highlightr
import Combine

#if canImport(UIKit)
import UIKit
#endif

#if canImport(AppKit)
import AppKit

final class LineNumberRulerView: NSRulerView {
    private weak var textView: NSTextView?
    private var lineStartOffsets = [0]

    init(textView: NSTextView, scrollView: NSScrollView) {
        self.textView = textView
        super.init(scrollView: scrollView, orientation: .verticalRuler)
        clientView = textView
        updateLineStarts()
    }

    required init(coder: NSCoder) {
        super.init(coder: coder)
    }

    func updateLineStarts() {
        guard let textView else { return }

        lineStartOffsets = [0]
        for (offset, codeUnit) in textView.string.utf16.enumerated() where codeUnit == 10 {
            lineStartOffsets.append(offset + 1)
        }

        let digitCount = String(lineStartOffsets.count).count
        ruleThickness = max(32, CGFloat(digitCount) * 9 + 14)
        needsDisplay = true
    }

    override func drawHashMarksAndLabels(in rect: NSRect) {
        guard let textView,
              let layoutManager = textView.layoutManager,
              let textContainer = textView.textContainer else {
            return
        }

        let glyphRange = layoutManager.glyphRange(forBoundingRect: textView.visibleRect, in: textContainer)
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .regular),
            .foregroundColor: NSColor.secondaryLabelColor
        ]
        var glyphIndex = glyphRange.location

        while glyphIndex < NSMaxRange(glyphRange) {
            var lineGlyphRange = NSRange()
            let lineRect = layoutManager.lineFragmentRect(forGlyphAt: glyphIndex, effectiveRange: &lineGlyphRange)
            let characterIndex = layoutManager.characterIndexForGlyph(at: lineGlyphRange.location)

            if let lineNumber = lineNumber(at: characterIndex) {
                let label = String(lineNumber) as NSString
                let size = label.size(withAttributes: attributes)
                let y = lineRect.minY + textView.textContainerOrigin.y + (lineRect.height - size.height) / 2
                label.draw(
                    at: NSPoint(x: ruleThickness - size.width - 7, y: y),
                    withAttributes: attributes
                )
            }

            glyphIndex = NSMaxRange(lineGlyphRange)
        }
    }

    private func lineNumber(at characterIndex: Int) -> Int? {
        var lowerBound = 0
        var upperBound = lineStartOffsets.count

        while lowerBound < upperBound {
            let midpoint = lowerBound + (upperBound - lowerBound) / 2
            if lineStartOffsets[midpoint] <= characterIndex {
                lowerBound = midpoint + 1
            } else {
                upperBound = midpoint
            }
        }

        guard lowerBound > 0, lineStartOffsets[lowerBound - 1] == characterIndex else {
            return nil
        }
        return lowerBound
    }
}
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
        scrollView.documentView = textView
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

        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        let lineNumberRulerView = LineNumberRulerView(textView: textView, scrollView: scrollView)
        scrollView.verticalRulerView = lineNumberRulerView
        scrollView.hasVerticalRuler = true
        scrollView.rulersVisible = true
        context.coordinator.lineNumberRulerView = lineNumberRulerView
        
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
        if context.coordinator.appliedText != text {
            textView.string = text
            context.coordinator.appliedText = text
            context.coordinator.updateLineNumberGutter()
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
        if context.coordinator.appliedText != text {
            if let storage = context.coordinator.storage {
                storage.replaceCharacters(in: NSRange(location: 0, length: storage.length), with: text)
            } else {
                uiView.text = text
            }
            context.coordinator.appliedText = text
        }
        context.coordinator.updateThemeIfNeeded()
    }
    #endif

    #if os(macOS)
    class Coordinator: NSObject, NSTextViewDelegate {
        var parent: SyntaxHighlightedTextEditor
        var scrollView: NSScrollView?
        var lineNumberRulerView: LineNumberRulerView?
        private var highlightr: Highlightr?
        private var storage: CodeAttributedString?
        private var cancellables = Set<AnyCancellable>()
        private var appliedThemeConfiguration: String?
        var appliedText: String?

        init(_ parent: SyntaxHighlightedTextEditor) {
            self.parent = parent
        }

        func setupTextView(_ textView: NSTextView) {
            highlightr = Highlightr()
            updateThemeIfNeeded()

            storage = CodeAttributedString(highlightr: highlightr!)
            storage!.language = "markdown"

            if let layoutManager = textView.layoutManager {
                storage!.addLayoutManager(layoutManager)
            }
            
            storage?.replaceCharacters(in: NSRange(location: 0, length: storage?.length ?? 0), with: parent.text)
            appliedText = parent.text
            
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
            lineNumberRulerView?.needsDisplay = true
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
            let configuration = themeConfiguration
            guard appliedThemeConfiguration != configuration else { return }
            appliedThemeConfiguration = configuration
            updateTheme()
        }

        private var themeConfiguration: String {
            let defaults = UserDefaults.standard
            return [
                parent.viewModel.editorTheme,
                String(defaults.double(forKey: "fontSize")),
                String(defaults.bool(forKey: "useCustomBgColor")),
                String(defaults.double(forKey: "customBgColorR")),
                String(defaults.double(forKey: "customBgColorG")),
                String(defaults.double(forKey: "customBgColorB")),
                String(defaults.bool(forKey: "wordWrap"))
            ].joined(separator: "|")
        }

        func updateLineNumberGutter() {
            lineNumberRulerView?.updateLineStarts()
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
            let updatedText = textView.string
            appliedText = updatedText
            self.parent.text = updatedText
            updateLineNumberGutter()
        }
    }
    #else
    class Coordinator: NSObject, UITextViewDelegate {
        var parent: SyntaxHighlightedTextEditor
        var textView: UITextView?
        private var highlightr: Highlightr?
        var storage: CodeAttributedString?
        private var cancellables = Set<AnyCancellable>()
        private var appliedThemeConfiguration: String?
        var appliedText: String?

        init(_ parent: SyntaxHighlightedTextEditor) {
            self.parent = parent
        }

        func setupTextView(_ textView: UITextView, highlightr: Highlightr, storage: CodeAttributedString) {
            self.highlightr = highlightr
            self.storage = storage
            
            updateThemeIfNeeded()

            storage.replaceCharacters(in: NSRange(location: 0, length: storage.length), with: parent.text)
            appliedText = parent.text
            
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
            let configuration = themeConfiguration
            guard appliedThemeConfiguration != configuration else { return }
            appliedThemeConfiguration = configuration
            updateTheme()
        }

        private var themeConfiguration: String {
            let defaults = UserDefaults.standard
            return [
                parent.viewModel.editorTheme,
                String(defaults.double(forKey: "fontSize")),
                String(defaults.bool(forKey: "useCustomBgColor")),
                String(defaults.double(forKey: "customBgColorR")),
                String(defaults.double(forKey: "customBgColorG")),
                String(defaults.double(forKey: "customBgColorB"))
            ].joined(separator: "|")
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
            appliedText = textView.text
            self.parent.text = textView.text
        }
    }
    #endif
}
