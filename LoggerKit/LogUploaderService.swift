//
//  LogUploaderService.swift
//  LoggerKit
//
//  Created by Vladimir Martemianov on 16.4.25..
//

import Foundation
import Combine
import UIKit
import ZIPFoundation

/// Service for archiving and uploading logs to a server
public class LogUploaderService: NSObject, URLSessionTaskDelegate {
    public var uploadProgress = CurrentValueSubject<Double, Never>(0.0)
    
    // MARK: - Types
    
    /// The result of an upload operation
    public enum UploadResult {
        case success(URL)          // Success, with the URL to the uploaded file
        case failure(Error)        // Error with details
        case cancelled             // Upload cancelled
    }
    
    /// Errors for the log upload service
    public enum LogUploadError: Error, LocalizedError {
        case noLogsFound                     // No logs found
        case archiveFailed(Error)            // Error during archiving
        case uploadFailed(Error)             // Error during upload
        case invalidServerResponse           // Invalid server response
        
        public var errorDescription: String? {
            switch self {
            case .noLogsFound:
                return "No logs were found"
            case .archiveFailed(let error):
                return "Error during log archiving: \(error.localizedDescription)"
            case .uploadFailed(let error):
                return "Error during log upload: \(error.localizedDescription)"
            case .invalidServerResponse:
                return "Invalid server response"
            }
        }
    }
    
    /// A global default endpoint used for uploading logs when none is explicitly provided.
    ///
    /// This can be set once and reused by calling `LogUploaderService.make()`
    /// without specifying an `endpoint` parameter.
    public static var globalUploadEndpoint: URL? = nil
    
    /// Creates and returns a configured instance of `LogUploaderService`.
    ///
    /// You can either provide a specific uploader instance, or allow this method to create one.
    /// If no endpoint is explicitly provided, it will fall back to `globalUploadEndpoint`.
    ///
    /// - Parameters:
    ///   - endpoint: The URL to which logs should be uploaded. Defaults to `globalUploadEndpoint`.
    ///   - authHeaders: Optional HTTP headers for authentication or metadata.
    ///   - timeoutInterval: Timeout for the upload request (default is 60 seconds).
    ///   - uploader: An existing `LogUploaderService` instance. If provided, it will be returned as-is.
    ///
    /// - Returns: A configured `LogUploaderService` instance, or `nil` if no valid endpoint is available.
    public static func make(
        endpoint: URL? = LogUploaderService.globalUploadEndpoint,
        authHeaders: [String: String] = [:],
        timeoutInterval: TimeInterval = 60.0,
        uploader: LogUploaderService? = nil
    ) -> LogUploaderService? {
        if let uploader = uploader {
            return uploader
        }
        guard let url = endpoint else { return nil }
        return LogUploaderService(endpoint: url, authHeaders: authHeaders, timeoutInterval: timeoutInterval)
    }
    
    /// Archiving options
    public struct ArchiveOptions {
        /// Include system logs
        let includeSystemLogs: Bool
        
        /// Include log backups (.1, .2, etc.)
        let includeBackups: Bool
        
        /// Maximum age of logs to include in the archive (in days)
        let maxAgeInDays: Int?
        
        /// Archive name (without extension)
        let archiveName: String
        
        /// Initializer with default settings
        public init(
            includeSystemLogs: Bool = true,
            includeBackups: Bool = false,
            maxAgeInDays: Int? = nil,
            archiveName: String? = nil
        ) {
            self.includeSystemLogs = includeSystemLogs
            self.includeBackups = includeBackups
            self.maxAgeInDays = maxAgeInDays
            
            if let name = archiveName {
                self.archiveName = name
            } else {
                let dateString = DateFormatter.compact.string(from: Date())
                self.archiveName = "logs_\(dateString)"
            }
        }
    }
    
    // MARK: - Properties
    
    /// The active upload task
    private var currentUploadTask: URLSessionUploadTask?
    
    /// URL of the endpoint for uploading logs
    private let uploadEndpoint: URL
    
    /// HTTP session settings
    private var session: URLSession
    
    /// Temporary directory for archives
    private let temporaryDirectory: URL
    
    /// Authorization headers for API requests
    private let authHeaders: [String: String]
    
    // MARK: - Initialization
    
    /// Initializes the log upload service
    /// - Parameters:
    ///   - endpoint: URL for uploading logs
    ///   - authHeaders: Authorization headers for the API
    ///   - timeoutInterval: Request timeout in seconds
    public init(
        endpoint: URL,
        authHeaders: [String: String] = [:],
        timeoutInterval: TimeInterval = 60.0
    ) {
        self.uploadEndpoint = endpoint
        self.authHeaders = authHeaders
        
        // Setting up the HTTP session
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = timeoutInterval
        configuration.timeoutIntervalForResource = timeoutInterval
        self.session = URLSession(configuration: configuration, delegate: nil, delegateQueue: nil)
        
        self.temporaryDirectory = FileManager.default.temporaryDirectory.appendingPathComponent("LogArchives", isDirectory: true)
        
        super.init() // call superclass init first
        
        try? FileManager.default.createDirectory(at: temporaryDirectory, withIntermediateDirectories: true)
        
        self.session = URLSession(configuration: configuration, delegate: self, delegateQueue: nil) // reassign after super.init
    }
    
    // MARK: - Public Methods
    
    /// Prepares log files for sending (copies to a temporary directory)
    /// - Parameter options: Archiving options
    /// - Returns: The result of the operation with a collection of files or an error
    public func prepareLogsForUpload(options: ArchiveOptions = ArchiveOptions()) -> Result<[URL], LogUploadError> {
        do {
            // Get the list of log files
            let logFiles = try getLogFilesToArchive(options: options)
            
            // Check that there are log files
            guard !logFiles.isEmpty else {
                return .failure(.noLogsFound)
            }
            
            // Create a temporary directory for this collection of logs
            let collectionDirectory = temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
            try FileManager.default.createDirectory(at: collectionDirectory, withIntermediateDirectories: true)
            
            // Copy files to the temporary directory
            var copiedFiles: [URL] = []
            for file in logFiles {
                let destinationURL = collectionDirectory.appendingPathComponent(file.lastPathComponent)
                try FileManager.default.copyItem(at: file, to: destinationURL)
                copiedFiles.append(destinationURL)
            }
            
            // Create a zip archive from the copied files
            let zipFileURL = collectionDirectory.appendingPathComponent("\(options.archiveName).zip")
            
            do {
                let archive = try Archive(url: zipFileURL, accessMode: .create)
                for fileURL in copiedFiles {
                    let fileName = fileURL.lastPathComponent
                    try archive.addEntry(with: fileName, fileURL: fileURL)
                }
            } catch {
                return .failure(.archiveFailed(error))
            }
            
            return .success([zipFileURL])
        } catch {
            return .failure(.archiveFailed(error))
        }
    }
    
    /// Uploads a collection of log files to the server
    /// - Parameters:
    ///   - logFiles: Array of file URLs to upload
    ///   - additionalInfo: Additional information to send along with the logs
    /// - Returns: Publisher with the upload result
    public func uploadLogs(
        _ logFiles: [URL],
        additionalInfo: [String: String] = [:]
    ) -> AnyPublisher<UploadResult, Never> {
        // Create a request object
        var request = URLRequest(url: uploadEndpoint)
        request.httpMethod = "POST"
        
        // Add authorization headers
        for (key, value) in authHeaders {
            request.setValue(value, forHTTPHeaderField: key)
        }
        
        // Create a multipart/form-data request
        let boundary = UUID().uuidString
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        // Form the request body
        let httpBody = createMultipartFormData(
            boundary: boundary,
            logFiles: logFiles,
            additionalInfo: additionalInfo
        )
        
        request.httpBody = httpBody
        
        // Execute the request
        return Future<UploadResult, Never> { promise in
            let task = self.session.uploadTask(with: request, from: httpBody) { data, response, error in
                defer {
                    self.cleanupTemporaryFiles(logFiles)
                }
                defer {
                    self.currentUploadTask = nil
                }
                if let error = error {
                    promise(.success(.failure(LogUploadError.uploadFailed(error))))
                    return
                }
                guard let httpResponse = response as? HTTPURLResponse else {
                    promise(.success(.failure(LogUploadError.invalidServerResponse)))
                    return
                }
                if (200...299).contains(httpResponse.statusCode) {
                    if let data = data, let responseURL = self.parseServerResponse(data: data) {
                        promise(.success(.success(responseURL)))
                    } else {
                        promise(.success(.success(self.uploadEndpoint)))
                    }
                } else {
                    let error = NSError(domain: "LogUploaderError", code: httpResponse.statusCode,
                                        userInfo: [NSLocalizedDescriptionKey: "Server returned status code: \(httpResponse.statusCode)"])
                    promise(.success(.failure(LogUploadError.uploadFailed(error))))
                }
            }
            self.currentUploadTask = task
            task.resume()
        }
        .eraseToAnyPublisher()
    }
    
    /// Prepares and uploads logs in one operation
    /// - Parameters:
    ///   - options: Archiving options
    ///   - additionalInfo: Additional information to send along with the logs
    /// - Returns: Publisher with the upload result
    public func prepareAndUploadLogs(
        options: ArchiveOptions = ArchiveOptions(),
        additionalInfo: [String: String] = [:]
    ) -> AnyPublisher<UploadResult, Never> {
        // Prepare the logs
        let prepareResult = prepareLogsForUpload(options: options)
        
        switch prepareResult {
        case .success(let logFiles):
            // If preparation is successful, upload the logs
            return uploadLogs(logFiles, additionalInfo: additionalInfo)
            
        case .failure(let error):
            // If preparation fails, return the error
            return Just(.failure(error))
                .eraseToAnyPublisher()
        }
    }
    
    /// Provides a set of log files for the share sheet
    /// - Parameter options: Archiving options
    /// - Returns: The result of the operation with an array of file URLs or an error
    public func prepareLogsForSharing(options: ArchiveOptions = ArchiveOptions()) -> Result<[URL], LogUploadError> {
        return prepareLogsForUpload(options: options)
    }
    
    /// Deletes all temporary files
    public func cleanupAllTemporaryFiles() {
        do {
            let fileManager = FileManager.default
            let files = try fileManager.contentsOfDirectory(at: temporaryDirectory, includingPropertiesForKeys: nil)
            
            for file in files {
                try fileManager.removeItem(at: file)
            }
        } catch {
            Log.system.error("Error cleaning up temporary files: \(error)")
        }
    }
    
    /// Cancels the current log upload task if it exists
    public func cancelUpload() {
        currentUploadTask?.cancel()
        currentUploadTask = nil
    }
    
    // MARK: - Private Methods
    
    /// Gets the list of log files to archive
    /// - Parameter options: Archiving options
    /// - Returns: Array of log URLs
    private func getLogFilesToArchive(options: ArchiveOptions) throws -> [URL] {
        let fileManager = FileManager.default
        let logsDirectory = Log.allLogFiles.first?.deletingLastPathComponent() ?? FileManager.default.temporaryDirectory
        
        // Check that the logs directory exists
        guard fileManager.fileExists(atPath: logsDirectory.path) else {
            return []
        }
        
        // Get all files from the logs directory
        let allFiles = try fileManager.contentsOfDirectory(at: logsDirectory, includingPropertiesForKeys: [.creationDateKey])
        
        // Filter files according to the settings
        return allFiles.filter { fileURL in
            // Check the file extension
            let isLogFile = fileURL.pathExtension == "log"
            
            // Check whether to include backups
            let isBackup = fileURL.lastPathComponent.contains(".log.")
            if isBackup && !options.includeBackups {
                return false
            }
            
            // Check whether to include system logs
            let isSystemLog = fileURL.lastPathComponent == "system.log"
            if isSystemLog && !options.includeSystemLogs {
                return false
            }
            
            // Check the file age
            if let maxAge = options.maxAgeInDays, let creationDate = try? fileURL.resourceValues(forKeys: [.creationDateKey]).creationDate {
                let calendar = Calendar.current
                if let daysAgo = calendar.dateComponents([.day], from: creationDate, to: Date()).day, daysAgo > maxAge {
                    return false
                }
            }
            
            return isLogFile
        }
    }
    
    /// Creates the multipart/form-data request body
    /// - Parameters:
    ///   - boundary: Boundary between multipart parts
    ///   - logFiles: Array of file URLs to upload
    ///   - additionalInfo: Additional information
    /// - Returns: Data for the request body
    private func createMultipartFormData(
        boundary: String,
        logFiles: [URL],
        additionalInfo: [String: String]
    ) -> Data {
        var body = Data()
        
        // Add additional fields
        for (key, value) in additionalInfo {
            body.append("--\(boundary)\r\n")
            body.append("Content-Disposition: form-data; name=\"\(key)\"\r\n\r\n")
            body.append("\(value)\r\n")
        }
        
        // Add device information
        let deviceInfo = collectDeviceInfo()
        for (key, value) in deviceInfo {
            body.append("--\(boundary)\r\n")
            body.append("Content-Disposition: form-data; name=\"device[\(key)]\"\r\n\r\n")
            body.append("\(value)\r\n")
        }
        
        // Add each log file
        for fileURL in logFiles {
            body.append("--\(boundary)\r\n")
            body.append("Content-Disposition: form-data; name=\"logs[]\"; filename=\"\(fileURL.lastPathComponent)\"\r\n")
            body.append("Content-Type: application/zip\r\n\r\n")
            
            // Add the file content
            if let fileData = try? Data(contentsOf: fileURL) {
                body.append(fileData)
                body.append("\r\n")
            }
        }
        
        // Close the multipart
        body.append("--\(boundary)--\r\n")
        
        return body
    }
    
    /// Collects device information
    /// - Returns: Dictionary with device information
    private func collectDeviceInfo() -> [String: String] {
        var info: [String: String] = [:]
        
        // System information
        let device = UIDevice.current
        info["model"] = device.model
        info["systemName"] = device.systemName
        info["systemVersion"] = device.systemVersion
        info["deviceName"] = device.name
        
        // Application information
        if let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String {
            info["appVersion"] = appVersion
        }
        
        if let buildNumber = Bundle.main.infoDictionary?["CFBundleVersion"] as? String {
            info["buildNumber"] = buildNumber
        }
        
        if let bundleId = Bundle.main.bundleIdentifier {
            info["bundleId"] = bundleId
        }
        
        // Current time
        info["timestamp"] = ISO8601DateFormatter().string(from: Date())
        
        return info
    }
    
    /// Parses the server response
    /// - Parameter data: Response data
    /// - Returns: URL from the server response, if possible
    private func parseServerResponse(data: Data) -> URL? {
        do {
            // Try to parse as JSON
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                // Look for URL in different possible fields
                if let urlString = json["url"] as? String ?? json["link"] as? String ?? json["fileUrl"] as? String {
                    return URL(string: urlString)
                }
            }
            return nil
        } catch {
            // If not JSON, try as a string
            if let responseText = String(data: data, encoding: .utf8), let url = URL(string: responseText.trimmingCharacters(in: .whitespacesAndNewlines)) {
                return url
            }
            return nil
        }
    }
    
    /// Deletes temporary files
    /// - Parameter files: URLs of the files to delete
    private func cleanupTemporaryFiles(_ files: [URL]) {
        for file in files {
            // If it's a directory, delete it entirely
            if file.hasDirectoryPath {
                try? FileManager.default.removeItem(at: file)
                continue
            }
            
            // Otherwise, delete the file itself
            try? FileManager.default.removeItem(at: file)
            
            // If the file is in a separate subdirectory, try to delete it as well
            let parentDir = file.deletingLastPathComponent()
            if parentDir.path.hasPrefix(temporaryDirectory.path) && parentDir.path != temporaryDirectory.path {
                // Check if the directory is empty
                if let contents = try? FileManager.default.contentsOfDirectory(at: parentDir, includingPropertiesForKeys: nil), contents.isEmpty {
                    try? FileManager.default.removeItem(at: parentDir)
                }
            }
        }
    }
    
    // MARK: - URLSessionTaskDelegate
    
    public func urlSession(_ session: URLSession, task: URLSessionTask, didSendBodyData bytesSent: Int64, totalBytesSent: Int64, totalBytesExpectedToSend: Int64) {
        let progress = Double(totalBytesSent) / Double(totalBytesExpectedToSend)
        uploadProgress.send(progress)
    }
}

// MARK: - Helper Extensions

extension DateFormatter {
    /// Compact date formatter for file names (YYYY-MM-DD_HHmmss)
    public static let compact: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HHmmss"
        return formatter
    }()
}

extension Data {
    /// Appends a string to the data using UTF8 encoding
    mutating func append(_ string: String) {
        if let data = string.data(using: .utf8) {
            append(data)
        }
    }
}


// MARK: - Example Usage

/*
 // Create the logging service
 let uploader = LogUploaderService(
 endpoint: URL(string: "https://api.example.com/upload-logs")!,
 authHeaders: ["Authorization": "Bearer YOUR-TOKEN"]
 )
 
 // Option 1: Prepare and upload logs in one operation
 uploader.prepareAndUploadLogs(
 options: LogUploaderService.ArchiveOptions(
 includeSystemLogs: true,
 includeBackups: true,
 maxAgeInDays: 7
 ),
 additionalInfo: ["user_id": "12345", "bug_report_id": "BUG-789"]
 )
 .sink(
 receiveCompletion: { completion in
 switch completion {
 case .finished:
 print("Upload completed")
 }
 },
 receiveValue: { result in
 switch result {
 case .success(let url):
 print("Logs uploaded successfully: \(url)")
 case .failure(let error):
 print("Error uploading logs: \(error.localizedDescription)")
 case .cancelled:
 print("Upload cancelled")
 }
 }
 )
 .store(in: &cancellables)
 
 // Option 2: Share log files
 let sharingResult = uploader.prepareLogsForSharing()
 switch sharingResult {
 case .success(let logFiles):
 // Show UIActivityViewController for sharing
 let activityViewController = UIActivityViewController(
 activityItems: logFiles,
 applicationActivities: nil
 )
 // Show the view controller
 presentingViewController.present(activityViewController, animated: true)
 case .failure(let error):
 print("Error preparing logs: \(error.localizedDescription)")
 }
 */
