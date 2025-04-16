import SwiftUI

// MARK: - LogViewerView Action Methods
extension LogViewerView {
    
    /// Clear the displayed log content
    func clearDisplayedLog() {
        // Stub implementation as a placeholder
        logContent = ""
        
        // You can also implement the actual functionality:
        // clearSelectedLogFile()
    }
    
    /// Clear the selected log file (with confirmation)
    func clearSelectedLogFile() {
        guard let fileURL = selectedLogFile else { return }
        
        let alert = UIAlertController(
            title: "Clear log file?",
            message: "Are you sure you want to delete all content from '\(fileURL.lastPathComponent)'?",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Clear", style: .destructive) { _ in
            do {
                try "".write(to: fileURL, atomically: true, encoding: .utf8)
                logContent = ""
            } catch {
                errorMessage = "Error clearing file: \(error.localizedDescription)"
            }
        })
        
        // Show alert
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootViewController = windowScene.windows.first?.rootViewController {
            rootViewController.present(alert, animated: true)
        }
    }
    
    /// Delete the selected log file
    func deleteSelectedLog() {
        guard let fileURL = selectedLogFile else { return }
        
        let alert = UIAlertController(
            title: "Delete log file?",
            message: "Are you sure you want to delete '\(fileURL.lastPathComponent)'?",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Delete", style: .destructive) { _ in
            do {
                try FileManager.default.removeItem(at: fileURL)
                
                // Update file list
                logFiles = logFiles.filter { $0 != fileURL }
                selectedLogFile = logFiles.first
                
                // Load content of the newly selected file
                loadLogContent()
            } catch {
                errorMessage = "Error deleting file: \(error.localizedDescription)"
            }
        })
        
        // Show alert
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootViewController = windowScene.windows.first?.rootViewController {
            rootViewController.present(alert, animated: true)
        }
    }
    
    /// Toggle auto-refresh
    func toggleAutoRefresh() {
        if autoRefresh {
            // Start timer
            timer = Timer.scheduledTimer(withTimeInterval: refreshInterval, repeats: true) { _ in
                loadLogContent()
            }
        } else {
            // Stop timer
            timer?.invalidate()
            timer = nil
        }
    }
    
    /// Share the log file
    func shareLogFile() {
        if let fileURL = selectedLogFile {
            let activityViewController = UIActivityViewController(
                activityItems: [fileURL],
                applicationActivities: nil
            )
            
            // Get UIWindow for presentation
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let rootViewController = windowScene.windows.first?.rootViewController {
                // On iPad, specify the source for popover
                if let popoverController = activityViewController.popoverPresentationController {
                    popoverController.barButtonItem = UIBarButtonItem()
                    popoverController.permittedArrowDirections = .any
                }
                rootViewController.present(activityViewController, animated: true)
            }
        }
    }
}