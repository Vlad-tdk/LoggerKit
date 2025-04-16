import SwiftUI

// MARK: - LogViewerView Extensions
extension LogViewerView {
    
    // MARK: - Methods and Computed Properties
    
    /// Checks if the log line contains the specified logging level
    func lineContainsLogLevel(_ line: String, level: Level) -> Bool {
        switch level {
        case .debug:
            return line.contains("[DEBUG]") || line.contains("[🔍 DEBUG]")
        case .info:
            return line.contains("[INFO]") || line.contains("[ℹ️ INFO]")
        case .warning:
            return line.contains("[WARNING]") || line.contains("[⚠️ WARNING]")
        case .error:
            return line.contains("[ERROR]") || line.contains("[❌ ERROR]")
        case .critical:
            return line.contains("[CRITICAL]") || line.contains("[🔥 CRITICAL]")
        }
    }
    
    /// Filtered log content
    var filteredLogContent: String {
        let lines = logContent.split(separator: "\n")
        
        return lines.filter { line in
            let lineString = String(line)
            
            // Filter by search query
            let matchesSearchText = searchText.isEmpty || lineString.localizedCaseInsensitiveContains(searchText)
            
            // Filter by logging level
            let matchesLevel: Bool
            if let level = filterLevel {
                matchesLevel = lineContainsLogLevel(lineString, level: level)
            } else {
                matchesLevel = true // Show all levels if no filter is selected
            }
            
            return matchesSearchText && matchesLevel
        }.joined(separator: "\n")
    }
    
    /// Text color for different logging levels
    func colorForLogLine(_ line: String) -> Color {
        if line.contains("[WARNING]") || line.contains("[⚠️ WARNING]") {
            return .orange
        } else if line.contains("[ERROR]") || line.contains("[❌ ERROR]") {
            return .red
        } else if line.contains("[CRITICAL]") || line.contains("[🔥 CRITICAL]") {
            return .red.opacity(0.8)
        } else if line.contains("[INFO]") || line.contains("[ℹ️ INFO]") {
            return .blue
        } else if line.contains("[DEBUG]") || line.contains("[🔍 DEBUG]") {
            return .gray
        } else {
            return .primary
        }
    }
    
    /// Load the list of log files
    func loadLogFiles() {
        logFiles = Log.allLogFiles.sorted { $0.lastPathComponent < $1.lastPathComponent }
        
        // If no file is selected and there are files - select the first one
        if selectedLogFile == nil && !logFiles.isEmpty {
            selectedLogFile = logFiles.first
            loadLogContent()
        }
    }
    
    /// Load the content of the selected log file
    func loadLogContent() {
        guard let fileURL = selectedLogFile else {
            logContent = "Select a log file to view"
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let content = try String(contentsOf: fileURL, encoding: .utf8)
                
                DispatchQueue.main.async {
                    logContent = content
                    isLoading = false
                }
            } catch {
                DispatchQueue.main.async {
                    logContent = ""
                    errorMessage = "Error loading file: \(error.localizedDescription)"
                    isLoading = false
                }
            }
        }
    }
    
    /// Hide the keyboard
    func hideKeyboard() {
        isSearchFieldFocused = false
    }
}
