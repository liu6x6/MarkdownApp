
import SwiftUI

struct EditorView: View {
    @EnvironmentObject var viewModel: AppViewModel

    var body: some View {
        // 使用我们自定义的、支持语法高亮的编辑器
        SyntaxHighlightedTextEditor(text: $viewModel.markdownText)
            .frame(minWidth: 300, idealWidth: 500, maxWidth: .infinity)
    }
}

struct EditorView_Previews: PreviewProvider {
    static var previews: some View {
        EditorView()
            .environmentObject(AppViewModel())
    }
}
