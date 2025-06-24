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
    
    /// Filtered log content with caching
    private static var lastFilterKey: String = ""
    private static var lastFilterResult: String = ""
    
    var filteredLogContent: String {
        // Create cache key
        let filterKey = "\(logContent.count)_\(searchText)_\(filterLevel?.rawValue ?? -1)"
        
        // Return cached result if nothing changed
        if filterKey == Self.lastFilterKey {
            return Self.lastFilterResult
        }
        
        let lines = logContent.split(separator: "\n")
        let result = lines.lazy.filter { line in
            let lineString = String(line)
            
            // Filter by search query
            guard searchText.isEmpty || lineString.localizedCaseInsensitiveContains(searchText) else {
                return false
            }
            
            // Filter by logging level
            if let level = filterLevel {
                return lineContainsLogLevel(lineString, level: level)
            }
            
            return true
        }.joined(separator: "\n")
        
        // Cache result
        Self.lastFilterKey = filterKey
        Self.lastFilterResult = result
        
        return result
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
