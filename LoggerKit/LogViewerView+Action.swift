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
        
        // Создаем alert через SwiftUI state
        let alert = Alert(
            title: Text("Clear log file?"),
            message: Text("Are you sure you want to delete all content from '\(fileURL.lastPathComponent)'?"),
            primaryButton: .destructive(Text("Clear")) {
                do {
                    try "".write(to: fileURL, atomically: true, encoding: .utf8)
                    logContent = ""
                } catch {
                    errorMessage = "Error clearing file: \(error.localizedDescription)"
                }
            },
            secondaryButton: .cancel()
        )
        
        // Показываем alert через состояние
        showClearAlert = true
    }
    
    /// Delete the selected log file
    func deleteSelectedLog() {
        guard let fileURL = selectedLogFile else { return }
        
        // Устанавливаем состояние для показа alert
        fileToDelete = fileURL
        showDeleteAlert = true
    }
    
    /// Выполняет удаление файла
    func performDelete() {
        guard let fileURL = fileToDelete else { return }
        
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
        
        fileToDelete = nil
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
            
            // Устанавливаем состояние для показа share sheet
            shareItems = [tempFileURL]
            
            // Добавляем текстовое содержимое для приложений, которые лучше работают с текстом
            if let logContent = String(data: logData, encoding: .utf8) {
                // Ограничиваем размер текста для предотвращения проблем с производительностью
                let maxTextLength = 10000
                let truncatedContent = logContent.count > maxTextLength ?
                String(logContent.prefix(maxTextLength)) + "\n\n... (truncated, see attached file for full content)" :
                logContent
                
                shareItems.append("Log file: \(fileName)\n\n\(truncatedContent)")
            }
            
            showShareSheet = true
            
        } catch {
            // В случае ошибки показываем простой share с URL
            errorMessage = "Error preparing file for sharing: \(error.localizedDescription)"
            
            // Fallback - делимся оригинальным файлом
            shareItems = [fileURL]
            showShareSheet = true
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
            shareItems = [
                exportedFileURL,
                "Application logs exported at \(DateFormatter.compact.string(from: Date()))"
            ]
            
            showShareSheet = true
            
            // Очищаем экспортированные файлы после завершения
            DispatchQueue.main.asyncAfter(deadline: .now() + 30) {
                exporter.clearExportDirectory()
            }
            
        case .failure(let error):
            errorMessage = "Error exporting logs: \(error.localizedDescription)"
        }
    }
}
