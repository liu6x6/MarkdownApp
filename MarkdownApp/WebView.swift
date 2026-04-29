
import SwiftUI
import WebKit
import Markdown
import Combine

struct WebView: PlatformViewRepresentable {
    @EnvironmentObject var viewModel: AppViewModel
    let markdown: String
    
    #if os(macOS)
    func makeNSView(context: Context) -> WKWebView {
        return createWebView(context: context)
    }

    func updateNSView(_ nsView: WKWebView, context: Context) {
        updateWebView(nsView, context: context)
    }
    #else
    func makeUIView(context: Context) -> WKWebView {
        return createWebView(context: context)
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {
        updateWebView(uiView, context: context)
    }
    #endif
    
    private func createWebView(context: Context) -> WKWebView {
        UserDefaults.standard.set(true, forKey: "WebKitDeveloperExtras")
        let prefs = WKWebpagePreferences()
        prefs.allowsContentJavaScript = true
        let config = WKWebViewConfiguration()
        config.defaultWebpagePreferences = prefs
        config.setValue(true, forKey: "allowUniversalAccessFromFileURLs")
        config.userContentController.add(context.coordinator, name: "scrollSync")
        config.userContentController.add(context.coordinator, name: "imagePreview")
        
        let webView = WKWebView(frame: .zero, configuration: config)
        
        #if os(macOS)
        // Enable Safari Web Inspector
        if #available(macOS 13.3, *) {
            webView.isInspectable = true
        } else {
            // For older macOS, this private pref enables it
            config.preferences.setValue(true, forKey: "developerExtrasEnabled")
        }
        #else
        if #available(iOS 16.4, *) {
            webView.isInspectable = true
        }
        #endif
        
        context.coordinator.webView = webView
        context.coordinator.subscribeToExportAction()
        context.coordinator.subscribeToScroll()
        return webView
    }

    private func updateWebView(_ webView: WKWebView, context: Context) {
        // Tie to the preview theme state so it updates when changed
        let _ = viewModel.previewTheme
        context.coordinator.updateContent(markdown)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, WKScriptMessageHandler {
        var parent: WebView
        var webView: WKWebView?
        private var cancellables = Set<AnyCancellable>()
        private var updateTimer: Timer?

        init(_ parent: WebView) {
            self.parent = parent
        }
        
        func updateContent(_ markdown: String) {
            updateTimer?.invalidate()
            updateTimer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: false) { [weak self] _ in
                guard let self = self else { return }
                guard let webView = self.webView else { return }
                
                let themeName = self.parent.viewModel.previewTheme
                let cssPath = Bundle.main.path(forResource: themeName, ofType: "css") ?? Bundle.main.path(forResource: "github", ofType: "css")
                let cssString = (try? String(contentsOfFile: cssPath ?? "")) ?? ""
                
                let encodedMarkdown = (try? String(data: JSONEncoder().encode(markdown), encoding: .utf8)) ?? "\"\""
                
                // Read from UserDefaults for typography
                let fontSize = UserDefaults.standard.double(forKey: "fontSize")
                let lineHeight = UserDefaults.standard.double(forKey: "lineHeight")
                let finalFontSize = fontSize > 0 ? fontSize : 14.0
                let finalLineHeight = lineHeight > 0 ? lineHeight : 1.5
                
                // Get local file URLs for JS and CSS
                let markedURL = Bundle.main.url(forResource: "marked.min", withExtension: "js")?.absoluteString ?? ""
                let hljsURL = Bundle.main.url(forResource: "highlight.min", withExtension: "js")?.absoluteString ?? ""
                let mermaidURL = Bundle.main.url(forResource: "mermaid.min", withExtension: "js")?.absoluteString ?? ""
                let hljsThemeLight = Bundle.main.url(forResource: "github-light.min", withExtension: "css")?.absoluteString ?? ""
                let hljsThemeDark = Bundle.main.url(forResource: "github-dark.min", withExtension: "css")?.absoluteString ?? ""
                
                let html = """
                <!DOCTYPE html>
                <html>
                <head>
                <meta charset="utf-8">
                <meta name="viewport" content="width=device-width, initial-scale=1">
                <style>
                :root {
                    font-size: \(finalFontSize)px;
                }
                body {
                    line-height: \(finalLineHeight);
                }
                \(cssString)
                \(JSHelper.Code.css)
                </style>
                <link rel="stylesheet" href="\(hljsThemeLight)" id="hljs-theme">
                <script src="\(markedURL)"></script>
                <script src="\(hljsURL)"></script>
                <script src="\(mermaidURL)"></script>
                </head>
                <body>
                <div id="content"></div>
                <script>
                    const isDarkMode = window.matchMedia && window.matchMedia('(prefers-color-scheme: dark)').matches;
                    if (isDarkMode) {
                        document.getElementById('hljs-theme').href = "\(hljsThemeDark)";
                    }

                    if (typeof mermaid !== 'undefined') {
                        mermaid.initialize({ startOnLoad: false, theme: isDarkMode ? 'dark' : 'default' });
                    }
                    
                    const renderer = new marked.Renderer();
                    const originalCodeRenderer = renderer.code.bind(renderer);
                    renderer.code = function(code, language, isEscaped) {
                        if (language === 'mermaid') {
                            return `<div class="mermaid">${code}</div>`;
                        }
                        const validLang = language || 'plaintext';
                        return '<pre><code class="language-' + validLang + '">' + code + '</code></pre>';
                    };
                    
                    marked.setOptions({ renderer: renderer });

                    const markdownText = \(encodedMarkdown);
                    document.getElementById('content').innerHTML = marked.parse(markdownText);
                    
                    // Trigger highlighting manually
                    if (typeof hljs !== 'undefined') {
                        hljs.highlightAll();
                    }
                    enhanceCodeBlocks(); //for copy
                    // Render Mermaid
                    if (typeof mermaid !== 'undefined') {
                        mermaid.init(undefined, document.querySelectorAll('.mermaid'));
                    }
                    
                    let isProgrammaticScroll = false;
                    
                    document.addEventListener('click', function(e) {
                        let img = e.target.closest('img');
                        if (img) {
                            window.webkit.messageHandlers.imagePreview.postMessage({type: 'img', data: img.src});
                            return;
                        }
                        let svg = e.target.closest('svg');
                        if (svg) {
                            window.webkit.messageHandlers.imagePreview.postMessage({type: 'svg', data: svg.outerHTML});
                            return;
                        }
                    });
                    /* 这段代码导致 webViw 滚动到 top
                    window.addEventListener('scroll', function() {
                        if (isProgrammaticScroll) {
                            isProgrammaticScroll = false;
                            return;
                        }
                        var maxY = document.documentElement.scrollHeight - window.innerHeight;
                        if (maxY > 0) {
                            var percentage = window.scrollY / maxY;
                            window.webkit.messageHandlers.scrollSync.postMessage(percentage);
                        }
                    });
                    
                    function scrollToPercentage(percentage) {
                        isProgrammaticScroll = true;
                        var maxY = document.documentElement.scrollHeight - window.innerHeight;
                        window.scrollTo(0, maxY * percentage);
                    } */
                \(JSHelper.Code.js)
                </script>
                </body>
                </html>
                """
                
                if let dir = self.parent.viewModel.currentDirectoryURL {
                    // Create a temporary hidden HTML file in the same directory to trick WebKit into allowing local image access
                    let tempFileURL = dir.appendingPathComponent(".preview-\(UUID().uuidString).html")
                    do {
                        try html.write(to: tempFileURL, atomically: true, encoding: .utf8)
                        webView.loadFileURL(tempFileURL, allowingReadAccessTo: dir)
                        
                        // Clean up the temp file after a short delay (enough time for WebKit to read it)
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                            try? FileManager.default.removeItem(at: tempFileURL)
                        }
                    } catch {
                        // Fallback to memory loading if we can't write
                        webView.loadHTMLString(html, baseURL: dir)
                    }
                } else {
                    webView.loadHTMLString(html, baseURL: nil)
                }
            }
        }

        func subscribeToExportAction() {
            parent.viewModel.exportAction.sink { [weak self] action in
                if action == .pdf {
                    self?.exportToPDF()
                }
            }
            .store(in: &cancellables)
        }
        
        func subscribeToScroll() {
            parent.viewModel.$scrollPercentage
                .receive(on: RunLoop.main)
                .sink { [weak self] percentage in
                    guard let self = self else { return }
                    guard self.parent.viewModel.scrollSource == .editor else { return }
                    
                    let js = "scrollToPercentage(\(percentage));"
                    self.webView?.evaluateJavaScript(js, completionHandler: nil)
                }
                .store(in: &cancellables)
        }
        
        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            if message.name == "scrollSync", let percentage = message.body as? CGFloat {
                parent.viewModel.scrollSource = .preview
                parent.viewModel.scrollPercentage = percentage
                
                DispatchQueue.main.async {
                    self.parent.viewModel.scrollSource = .none
                }
            } else if message.name == "imagePreview", let dict = message.body as? [String: String], let type = dict["type"], let data = dict["data"] {
                DispatchQueue.main.async {
                    self.parent.viewModel.imagePreview = ImagePreviewData(type: type, data: data)
                }
            }
        }

        func exportToPDF() {
            #if os(macOS)
            let savePanel = NSSavePanel()
            if #available(macOS 11.0, *) {
                savePanel.allowedContentTypes = [.pdf]
            } else {
                savePanel.allowedFileTypes = ["pdf"]
            }
            if savePanel.runModal() == .OK {
                if let url = savePanel.url {
                    // Modern API to generate PDF safely
                    let pdfConfig = WKPDFConfiguration()
                    // Set print margins or rects if needed
                    let workItem = DispatchWorkItem { [weak self] in
                        guard let webView = self?.webView else { return }
                        if webView.frame.isEmpty {
                            webView.frame = CGRect(x: 0, y: 0, width: 800, height: 600)
                        }
                        webView.createPDF(configuration: pdfConfig) { result in
                            let resultWorkItem = DispatchWorkItem {
                                switch result {
                                case .success(let data):
                                    do {
                                        try data.write(to: url)
                                    } catch {
                                        self?.parent.viewModel.appError = AppError(title: "导出 PDF 失败", message: error.localizedDescription)
                                    }
                                case .failure(let error):
                                    self?.parent.viewModel.appError = AppError(title: "生成 PDF 失败", message: error.localizedDescription)
                                }
                            }
                            DispatchQueue.main.async(execute: resultWorkItem)
                        }
                    }
                    DispatchQueue.main.async(execute: workItem)
                }
            }
            #else
            // iOS implementation for PDF export (placeholder for now)
            parent.viewModel.appError = AppError(title: "提示", message: "iOS 暂不支持直接导出 PDF，敬请期待")
            #endif
        }
        
        deinit {
            updateTimer?.invalidate()
        }
    }
}
