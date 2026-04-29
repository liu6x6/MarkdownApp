import Foundation

extension AppViewModel {
    func loadSampleFilesIfNeeded() {
        guard let documentsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else { return }
        
        let sampleFiles = [
            "RN与SwiftUI核心概念对比",
            "resources_arsc_解析",
            "RF_Get_Tx_Power_Report_Guide"
        ]
        
        var didCopy = false
        
        for fileName in sampleFiles {
            let destURL = documentsDir.appendingPathComponent("\(fileName).md")
            if !FileManager.default.fileExists(atPath: destURL.path) {
                if let srcURL = Bundle.main.url(forResource: fileName, withExtension: "md") {
                    do {
                        try FileManager.default.copyItem(at: srcURL, to: destURL)
                        didCopy = true
                    } catch {
                        print("Failed to copy sample file \(fileName): \(error)")
                    }
                }
            }
        }
        
        #if os(iOS)
        // Auto load documents directory on iOS on first launch
        self.currentDirectoryURL = documentsDir
        loadFiles(from: documentsDir)
        
        if didCopy || self.currentFilePath == nil {
            if let firstFile = self.filePaths.first {
                self.selectFile(at: firstFile)
            }
        }
        #endif
    }
}