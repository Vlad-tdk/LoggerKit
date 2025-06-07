import SwiftUI

import SwiftUI

// MARK: - LogViewerView Action Methods
extension LogViewerView {
    
    /// Clear the displayed log content
    func clearDisplayedLog() {
        logContent = ""
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
    
    /// Share the log file with improved compatibility for email and messaging apps
    func shareLogFile() {
        guard let fileURL = selectedLogFile else { return }
        
        do {
            // Читаем содержимое файла
            let logData = try Data(contentsOf: fileURL)
            let fileName = fileURL.lastPathComponent
            
            // Создаем временный файл с читаемым именем для лучшей совместимости
            let tempDir = FileManager.default.temporaryDirectory
            let tempFileURL = tempDir.appendingPathComponent("SharedLog_\(fileName)")
            
            // Записываем данные во временный файл
            try logData.write(to: tempFileURL)
            
            // Создаем элементы для шаринга
            var activityItems: [Any] = []
            
            // Добавляем временный файл
            activityItems.append(tempFileURL)
            
            // Добавляем текстовое содержимое для приложений, которые лучше работают с текстом
            if let logContent = String(data: logData, encoding: .utf8) {
                // Ограничиваем размер текста для предотвращения проблем с производительностью
                let maxTextLength = 10000
                let truncatedContent = logContent.count > maxTextLength ?
                String(logContent.prefix(maxTextLength)) + "\n\n... (truncated, see attached file for full content)" :
                logContent
                
                activityItems.append("Log file: \(fileName)\n\n\(truncatedContent)")
            }
            
            let activityViewController = UIActivityViewController(
                activityItems: activityItems,
                applicationActivities: nil
            )
            
            // Исключаем некоторые активности, которые могут не подходить для логов
            activityViewController.excludedActivityTypes = [
                .assignToContact,
                .addToReadingList,
                .openInIBooks
            ]
            
            // Добавляем обработчик завершения для очистки временного файла
            activityViewController.completionWithItemsHandler = { _, _, _, _ in
                // Удаляем временный файл после завершения
                try? FileManager.default.removeItem(at: tempFileURL)
            }
            
            // Get UIWindow for presentation
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let rootViewController = windowScene.windows.first?.rootViewController {
                
                // На iPad указываем источник для popover
                if let popoverController = activityViewController.popoverPresentationController {
                    // Пытаемся найти представление для привязки popover
                    popoverController.sourceView = rootViewController.view
                    popoverController.sourceRect = CGRect(x: rootViewController.view.bounds.midX,
                                                          y: rootViewController.view.bounds.midY,
                                                          width: 0, height: 0)
                    popoverController.permittedArrowDirections = []
                }
                
                rootViewController.present(activityViewController, animated: true)
            }
            
        } catch {
            // В случае ошибки показываем простой share с URL
            errorMessage = "Error preparing file for sharing: \(error.localizedDescription)"
            
            // Fallback - делимся оригинальным файлом
            let activityViewController = UIActivityViewController(
                activityItems: [fileURL],
                applicationActivities: nil
            )
            
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let rootViewController = windowScene.windows.first?.rootViewController {
                
                if let popoverController = activityViewController.popoverPresentationController {
                    popoverController.sourceView = rootViewController.view
                    popoverController.sourceRect = CGRect(x: rootViewController.view.bounds.midX,
                                                          y: rootViewController.view.bounds.midY,
                                                          width: 0, height: 0)
                    popoverController.permittedArrowDirections = []
                }
                
                rootViewController.present(activityViewController, animated: true)
            }
        }
    }
    
    /// Создает и делится ZIP архивом с логами для лучшей совместимости с email
    func shareLogsAsArchive() {
        guard !logFiles.isEmpty else { return }
        
        let exporter = LogExporterService()
        
        // Подготавливаем логи для экспорта
        let result = exporter.exportAllLogs(
            format: .json, // JSON лучше читается в email
            options: LogExporterService.ExportOptions(
                maxEntries: 1000, // Ограничиваем количество записей
                reverseOrder: true // Новые записи сверху
            )
        )
        
        switch result {
        case .success(let exportedFileURL):
            // Создаем элементы для шаринга
            let activityItems: [Any] = [
                exportedFileURL,
                "Application logs exported at \(DateFormatter.compact.string(from: Date()))"
            ]
            
            let activityViewController = UIActivityViewController(
                activityItems: activityItems,
                applicationActivities: nil
            )
            
            activityViewController.excludedActivityTypes = [
                .assignToContact,
                .addToReadingList,
                .openInIBooks
            ]
            
            // Очищаем экспортированные файлы после завершения
            activityViewController.completionWithItemsHandler = { _, _, _, _ in
                exporter.clearExportDirectory()
            }
            
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let rootViewController = windowScene.windows.first?.rootViewController {
                
                if let popoverController = activityViewController.popoverPresentationController {
                    popoverController.sourceView = rootViewController.view
                    popoverController.sourceRect = CGRect(x: rootViewController.view.bounds.midX,
                                                          y: rootViewController.view.bounds.midY,
                                                          width: 0, height: 0)
                    popoverController.permittedArrowDirections = []
                }
                
                rootViewController.present(activityViewController, animated: true)
            }
            
        case .failure(let error):
            errorMessage = "Error exporting logs: \(error.localizedDescription)"
        }
    }
}
