import SwiftUI

struct SettingsView: View {
    @AppStorage("editorTheme") private var editorTheme: String = "xcode"
    @AppStorage("previewTheme") private var previewTheme: String = "github"
    @AppStorage("fontSize") private var fontSize: Double = 14.0
    @AppStorage("lineHeight") private var lineHeight: Double = 1.5
    @AppStorage("wordWrap") private var wordWrap: Bool = true
    
    @AppStorage("useCustomBgColor") private var useCustomBgColor: Bool = false
    @AppStorage("customBgColorR") private var customBgR: Double = 1.0
    @AppStorage("customBgColorG") private var customBgG: Double = 1.0
    @AppStorage("customBgColorB") private var customBgB: Double = 1.0
    
    private let themes = ["xcode", "github", "github-dark", "dracula", "nord", "monokai", "atom-one-dark", "vs2015", "solarized-dark", "solarized-light"]
    private let previewThemes = ["github", "modern", "classic", "notion", "dracula"]
    
    var body: some View {
        TabView {
            GeneralSettingsView(
                editorTheme: $editorTheme,
                previewTheme: $previewTheme,
                useCustomBgColor: $useCustomBgColor,
                customBgR: $customBgR,
                customBgG: $customBgG,
                customBgB: $customBgB,
                themes: themes,
                previewThemes: previewThemes
            )
            .tabItem {
                Label("通用与外观", systemImage: "paintbrush")
            }
            .tag("general")
            
            EditorSettingsView(fontSize: $fontSize, lineHeight: $lineHeight, wordWrap: $wordWrap)
                .tabItem {
                    Label("编辑器设置", systemImage: "text.alignleft")
                }
                .tag("editor")
        }
        .padding(20)
#if os(macOS)
        .frame(width: 480, height: 350)
#endif

    }
}

struct GeneralSettingsView: View {
    @Binding var editorTheme: String
    @Binding var previewTheme: String
    @Binding var useCustomBgColor: Bool
    @Binding var customBgR: Double
    @Binding var customBgG: Double
    @Binding var customBgB: Double
    
    let themes: [String]
    let previewThemes: [String]
    
    private var customColorBinding: Binding<Color> {
        Binding(
            get: {
                Color(red: customBgR, green: customBgG, blue: customBgB)
            },
            set: { newColor in
                #if os(macOS)
                if let nsColor = NSColor(newColor).usingColorSpace(.deviceRGB) {
                    customBgR = Double(nsColor.redComponent)
                    customBgG = Double(nsColor.greenComponent)
                    customBgB = Double(nsColor.blueComponent)
                }
                #else
                let uiColor = UIColor(newColor)
                var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
                if uiColor.getRed(&r, green: &g, blue: &b, alpha: &a) {
                    customBgR = Double(r)
                    customBgG = Double(g)
                    customBgB = Double(b)
                }
                #endif
            }
        )
    }
    
    var body: some View {
        Form {
            Section(header: Text("主题设置").font(.headline)) {
                Picker("编辑器主题:", selection: $editorTheme) {
                    ForEach(themes, id: \.self) { theme in
                        Text(theme).tag(theme)
                    }
                }
                .pickerStyle(.menu)
                .padding(.bottom, 10)
                
                Picker("默认预览主题:", selection: $previewTheme) {
                    ForEach(previewThemes, id: \.self) { theme in
                        Text(theme.capitalized).tag(theme)
                    }
                }
                .pickerStyle(.menu)
            }
            .padding(.bottom, 15)
            
            Section(header: Text("背景设置").font(.headline)) {
                Toggle("自定义编辑器背景颜色", isOn: $useCustomBgColor)
                
                if useCustomBgColor {
                    ColorPicker("选择背景色:", selection: customColorBinding)
                } else {
                    Text("当前使用编辑器主题的默认背景色")
                        .foregroundColor(.secondary)
                        .font(.caption)
                }
            }
            
            Spacer()
        }
        .padding()
    }
}

struct EditorSettingsView: View {
    @Binding var fontSize: Double
    @Binding var lineHeight: Double
    @Binding var wordWrap: Bool
    
    var body: some View {
        Form {
            Section(header: Text("排版与字体").font(.headline)) {
                HStack {
                    Text("字体大小:")
                    Slider(value: $fontSize, in: 10...30, step: 1)
                    Text("\(Int(fontSize)) pt")
                        .frame(width: 40, alignment: .trailing)
                }
                .padding(.bottom, 10)
                
                HStack {
                    Text("行高比例:")
                    Slider(value: $lineHeight, in: 1.0...2.5, step: 0.1)
                    Text(String(format: "%.1f", lineHeight))
                        .frame(width: 40, alignment: .trailing)
                }
                .padding(.bottom, 10)
                
                Toggle("启用自动换行 (Word Wrap)", isOn: $wordWrap)
            }
            .padding()
            
            Spacer()
        }
    }
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
    }
}
