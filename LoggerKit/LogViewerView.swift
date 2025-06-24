//
//   LogViewerView.swift
//   LoggerKit
//
//   Created by Vladimir Martemianov on 16.4.25.
//

//   LogViewerView.swift
//   LoggerKit
//
//   Created by Vladimir Martemianov on 16.4.25.
//

import SwiftUI
import Combine

/// SwiftUI component for viewing log file contents directly in the application
public struct LogViewerView: View {
    // MARK: - Properties
    
    /// List of available log files
    @State var logFiles: [URL] = []
    
    /// Selected log file
    @State var selectedLogFile: URL?
    
    /// Content of the selected log file
    @State var logContent: String = ""
    
    /// Loading indicator
    @State var isLoading: Bool = false
    
    /// Error message
    @State var errorMessage: String?
    
    /// Search text for logs
    @State var searchText: String = ""
    
    /// Minimum logging level to display
    @State var filterLevel: Level? = nil
    
    /// Automatic log updates
    @State var autoRefresh: Bool = false
    
    /// Timer for auto-refresh
    @State var timer: Timer?
    
    /// Auto-refresh interval in seconds
    @State var refreshInterval: TimeInterval = 5.0
    
    /// Focus state for the search field
    @FocusState var isSearchFieldFocused: Bool
    
    @State private var uploadProgress: Double = 0.0
    @State private var isUploading: Bool = false
    @State private var uploader: LogUploaderService? = nil
    @State private var cancellables: Set<AnyCancellable> = []
    
    // MARK: - Alert and Share Sheet States
    @State var showDeleteAlert: Bool = false
    @State var showClearAlert: Bool = false
    @State var showShareSheet: Bool = false
    @State var shareItems: [Any] = []
    @State var fileToDelete: URL? = nil
    
    // MARK: - Initialization and Deinitialization
    
    public init() {
    }
    
    // MARK: - Body
    
    public var body: some View {
        NavigationView {
            ZStack {
                Color(UIColor.systemGroupedBackground)
                    .edgesIgnoringSafeArea(.all)
                    .onTapGesture {
                        hideKeyboard()
                    }
                
                VStack(spacing: 12) {
                    // Log file selector
                    logFileSelector
                    
                    // Search field with improved design
                    searchField
                    
                    // Log level filter
                    logLevelFilter
                    
                    // Log content with improved design
                    logContentView
                    
                    // Improved toolbar
                    toolbarView
                }
                .padding(.vertical)
            }
            .navigationTitle("Log Viewer")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    if isUploading {
                        HStack {
                            ProgressView(value: uploadProgress)
                                .frame(width: 80)
                            Button(action: {
                                uploader?.cancelUpload()
                            }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.red)
                            }
                        }
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        guard let file = selectedLogFile else { return }
                        isUploading = true
                        uploadProgress = 0.0
                        
                        guard let uploaderService = Logger.makeUploader() else {
                            print("❌ LogUploaderService is not configured via Logger")
                            isUploading = false
                            return
                        }
                        
                        uploader = uploaderService
                        
                        uploaderService.uploadLogs([file])
                            .receive(on: DispatchQueue.main)
                            .sink { result in
                                isUploading = false
                                switch result {
                                case .success(let url):
                                    print("Uploaded to: \(url)")
                                case .failure(let error):
                                    print("Upload failed: \(error)")
                                case .cancelled:
                                    print("Upload cancelled")
                                }
                            }
                            .store(in: &cancellables)
                        
                        uploaderService.uploadProgress
                            .receive(on: DispatchQueue.main)
                            .sink { progress in
                                self.uploadProgress = progress
                            }
                            .store(in: &cancellables)
                    }) {
                        Image(systemName: "square.and.arrow.up")
                    }
                    .disabled(selectedLogFile == nil || isUploading)
                }
            }
            // MARK: - Alerts and Sheets
            .alert("Delete log file?", isPresented: $showDeleteAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Delete", role: .destructive) {
                    performDelete()
                }
            } message: {
                if let fileURL = fileToDelete {
                    Text("Are you sure you want to delete '\(fileURL.lastPathComponent)'?")
                }
            }
            .alert("Clear log file?", isPresented: $showClearAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Clear", role: .destructive) {
                    guard let fileURL = selectedLogFile else { return }
                    do {
                        try "".write(to: fileURL, atomically: true, encoding: .utf8)
                        logContent = ""
                    } catch {
                        errorMessage = "Error clearing file: \(error.localizedDescription)"
                    }
                }
            } message: {
                if let fileURL = selectedLogFile {
                    Text("Are you sure you want to delete all content from '\(fileURL.lastPathComponent)'?")
                }
            }
            .sheet(isPresented: $showShareSheet, onDismiss: {
                // Очищаем временные файлы после закрытия share sheet
                cleanupTempFiles()
            }) {
                if !shareItems.isEmpty {
                    ActivityViewController(activityItems: shareItems)
                }
            }
        }
        .onAppear {
            loadLogFiles()
        }
        .onDisappear {
            timer?.invalidate()
            timer = nil
            cancellables.removeAll()
            uploader?.cancelUpload()
            uploader = nil
            cleanupTempFiles()
        }
        .onTapGesture {
            // Additional check to hide keyboard when tapping anywhere
            hideKeyboard()
        }
    }
    
    // MARK: - UI Components
    
    private var logFileSelector: some View {
        HStack {
            Image(systemName: "doc.text")
                .foregroundColor(.blue)
            
            Picker("", selection: $selectedLogFile) {
                ForEach(logFiles, id: \.self) { file in
                    Text(file.lastPathComponent).tag(file as URL?)
                }
            }
            .pickerStyle(MenuPickerStyle())
            .onChange(of: selectedLogFile) { _, _ in
                loadLogContent()
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(UIColor.secondarySystemBackground))
        )
        .padding(.horizontal)
    }
    
    private var searchField: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.gray)
            
            TextField("Search in log", text: $searchText)
                .textFieldStyle(PlainTextFieldStyle())
                .focused($isSearchFieldFocused)
                .submitLabel(.search)
                .onSubmit {
                    hideKeyboard()
                }
            
            if !searchText.isEmpty {
                Button(action: {
                    searchText = ""
                    hideKeyboard()
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.gray)
                }
                .buttonStyle(BorderlessButtonStyle())
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(UIColor.secondarySystemBackground))
        )
        .padding(.horizontal)
    }
    
    private var logLevelFilter: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Logging Level:")
                .font(.footnote)
                .foregroundColor(.secondary)
                .padding(.horizontal, 4)
            
            Picker("", selection: $filterLevel) {
                Text("All").tag(nil as Level?)
                Text("Debug").tag(Level.debug as Level?)
                Text("Info").tag(Level.info as Level?)
                Text("Warning").tag(Level.warning as Level?)
                Text("Error").tag(Level.error as Level?)
                Text("Critical").tag(Level.critical as Level?)
            }
            .pickerStyle(SegmentedPickerStyle())
            .onChange(of: filterLevel) {_, _ in
                hideKeyboard()
            }
        }
        .padding(.horizontal)
    }
    
    private var logContentView: some View {
        ZStack {
            if isLoading {
                ProgressView("Loading...")
                    .progressViewStyle(CircularProgressViewStyle())
            } else if let error = errorMessage {
                VStack {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.largeTitle)
                        .foregroundColor(.red)
                    Text(error)
                        .multilineTextAlignment(.center)
                        .padding()
                }
            } else {
                ScrollViewReader { scrollView in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 2) {
                            ForEach(Array(filteredLogContent.split(separator: "\n").enumerated()), id: \.offset) { index, line in
                                let lineText = String(line)
                                Text(lineText)
                                    .font(.system(.caption, design: .monospaced))
                                    .foregroundColor(colorForLogLine(lineText))
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 1)
                                    .id(index)
                                    .contentShape(Rectangle())
                                    .onTapGesture {
                                        hideKeyboard()
                                    }
                            }
                        }
                        .padding(.vertical, 8)
                    }
                    .background(Color(UIColor.systemBackground))
                    .onTapGesture {
                        hideKeyboard()
                    }
                    .onChange(of: logContent) {_, _ in
                        // Scroll to the last line when content updates
                        if !logContent.isEmpty {
                            let lines = logContent.split(separator: "\n")
                            if !lines.isEmpty {
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                    withAnimation {
                                        scrollView.scrollTo(lines.count - 1, anchor: .bottom)
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
        )
        .padding(.horizontal)
    }
    
    private var toolbarView: some View {
        HStack(spacing: 16) {
            // Refresh button
            Button(action: loadLogContent) {
                VStack {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 18))
                    Text("Refresh")
                        .font(.caption)
                }
            }
            .buttonStyle(BorderlessButtonStyle())
            
            Spacer()
            
            // Auto-refresh toggle
            VStack {
                Toggle("", isOn: $autoRefresh)
                    .toggleStyle(SwitchToggleStyle(tint: .blue))
                    .labelsHidden()
                Text("Auto-refresh")
                    .font(.caption)
            }
            .onChange(of: autoRefresh) {_, _ in
                toggleAutoRefresh()
            }
            
            Spacer()
            
            // Export single file button
            Button(action: shareLogFile) {
                VStack {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 18))
                    Text("Share File")
                        .font(.caption)
                }
            }
            .buttonStyle(BorderlessButtonStyle())
            .disabled(selectedLogFile == nil)
            
            // Export all logs as archive button
            Button(action: shareLogsAsArchive) {
                VStack {
                    Image(systemName: "archivebox")
                        .font(.system(size: 18))
                    Text("Share All")
                        .font(.caption)
                }
            }
            .buttonStyle(BorderlessButtonStyle())
            .disabled(logFiles.isEmpty)
            
            // Clear button
            Button(action: {
                showClearAlert = true
            }) {
                VStack {
                    Image(systemName: "clear")
                        .font(.system(size: 18))
                    Text("Clear")
                        .font(.caption)
                }
            }
            .buttonStyle(BorderlessButtonStyle())
            .disabled(selectedLogFile == nil)
            
            // Delete button
            Button(action: deleteSelectedLog) {
                VStack {
                    Image(systemName: "trash")
                        .font(.system(size: 18))
                    Text("Delete")
                        .font(.caption)
                }
            }
            .buttonStyle(BorderlessButtonStyle())
            .foregroundColor(.red)
            .disabled(selectedLogFile == nil)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(UIColor.secondarySystemBackground))
        )
        .padding(.horizontal)
    }
    
    // MARK: - Helper Methods
    
    private func cleanupTempFiles() {
        shareItems.removeAll()
        
        // Удаляем временные файлы если они есть
        for item in shareItems {
            if let url = item as? URL, url.path.contains("SharedLog_") {
                try? FileManager.default.removeItem(at: url)
            }
        }
    }
}

// MARK: - ActivityViewController Wrapper
struct ActivityViewController: UIViewControllerRepresentable {
    let activityItems: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(
            activityItems: activityItems,
            applicationActivities: nil
        )
        
        controller.excludedActivityTypes = [
            .assignToContact,
            .addToReadingList,
            .openInIBooks
        ]
        
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {
        // No updates needed
    }
}
