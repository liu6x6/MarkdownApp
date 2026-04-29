import SwiftUI
import WebKit

struct ImagePreviewView: View {
    let previewData: ImagePreviewData
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(previewData.type == "svg" ? "图表预览 (可缩放)" : "图片预览 (可缩放)")
                    .font(.headline)
                Spacer()
                Button(action: saveImage) {
                    Image(systemName: "square.and.arrow.down")
                        .font(.title2)
                }
                .buttonStyle(.plain)
                .padding(.trailing, 10)
                
                Button(action: {
                    presentationMode.wrappedValue.dismiss()
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(.red)
                }
                .buttonStyle(.plain)
                .keyboardShortcut(.escape, modifiers: [])
            }
            .padding()
            #if os(macOS)
            .background(Color(NSColor.controlBackgroundColor))
            #else
            .background(Color(UIColor.systemBackground))
            #endif
            
            Divider()
            
            PreviewWebView(type: previewData.type, data: previewData.data)
                .frame(minWidth: 1000, idealWidth: 1200, maxWidth: .infinity, minHeight: 700, idealHeight: 800, maxHeight: .infinity)
        }
        .frame(minWidth: 1000, idealWidth: 1200, maxWidth: .infinity, minHeight: 700, idealHeight: 800, maxHeight: .infinity)
    }
    
    func saveImage() {
        #if os(macOS)
        let savePanel = NSSavePanel()
        if previewData.type == "svg" {
            if #available(macOS 11.0, *) {
                savePanel.allowedContentTypes = [.svg]
            } else {
                savePanel.allowedFileTypes = ["svg"]
            }
            savePanel.nameFieldStringValue = "diagram.svg"
        } else {
            if #available(macOS 11.0, *) {
                savePanel.allowedContentTypes = [.image]
            } else {
                savePanel.allowedFileTypes = ["png", "jpg", "jpeg", "gif"]
            }
            if let url = URL(string: previewData.data), url.isFileURL {
                savePanel.nameFieldStringValue = url.lastPathComponent
            } else {
                savePanel.nameFieldStringValue = "image.png"
            }
        }
        
        if savePanel.runModal() == .OK, let url = savePanel.url {
            do {
                if previewData.type == "svg" {
                    try previewData.data.write(to: url, atomically: true, encoding: .utf8)
                } else {
                    if let imgUrl = URL(string: previewData.data) {
                        let imgData = try Data(contentsOf: imgUrl)
                        try imgData.write(to: url)
                    }
                }
            } catch {
                print("Save error: \(error)")
            }
        }
        #else
        print("Save image not implemented for iOS yet.")
        #endif
    }
}

struct PreviewWebView: PlatformViewRepresentable {
    let type: String
    let data: String
    
    #if os(macOS)
    func makeNSView(context: Context) -> WKWebView {
        return createWebView()
    }
    
    func updateNSView(_ webView: WKWebView, context: Context) {
        updateWebView(webView)
    }
    #else
    func makeUIView(context: Context) -> WKWebView {
        return createWebView()
    }
    
    func updateUIView(_ uiView: WKWebView, context: Context) {
        updateWebView(uiView)
    }
    #endif
    
    private func createWebView() -> WKWebView {
        let prefs = WKWebpagePreferences()
        prefs.allowsContentJavaScript = true
        let config = WKWebViewConfiguration()
        config.defaultWebpagePreferences = prefs
        let webView = WKWebView(frame: .zero, configuration: config)
        
        #if os(macOS)
        // Enable pinch to zoom native to WKWebView on macOS
        webView.allowsMagnification = true
        #endif
        return webView
    }
    
    private func updateWebView(_ webView: WKWebView) {
        let html: String
        #if os(macOS)
        let isDarkMode = NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        #else
        // Just a simple default for iOS right now
        let isDarkMode = false
        #endif
        let bgColor = isDarkMode ? "#1e1e1e" : "#f5f5f5"
        
        if type == "svg" {
            html = """
            <!DOCTYPE html>
            <html><body style="display:flex;justify-content:center;align-items:center;height:100vh;margin:0;background-color:\(bgColor);">
            \(data)
            </body></html>
            """
        } else {
            html = """
            <!DOCTYPE html>
            <html><body style="display:flex;justify-content:center;align-items:center;height:100vh;margin:0;background-color:\(bgColor);">
            <img src="\(data)" style="max-width:100%;max-height:100%;object-fit:contain;" />
            </body></html>
            """
        }
        webView.loadHTMLString(html, baseURL: nil)
    }
}