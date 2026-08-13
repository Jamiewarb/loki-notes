import Foundation
import LociCore

/// Thin coordinated I/O wrapper.
/// On Apple platforms uses `NSFileCoordinator`; on Linux uses plain `FileManager`
/// so unit tests and CI stay green without ubiquity.
public struct FileCoordinatorClient: Sendable {
    public init() {}

    public func readData(at url: URL) throws -> Data {
        try coordinate(readingItemAt: url) { readURL in
            try Data(contentsOf: readURL)
        }
    }

    public func writeData(_ data: Data, to url: URL) throws {
        try coordinate(writingItemAt: url) { writeURL in
            let parent = writeURL.deletingLastPathComponent()
            try FileManager.default.createDirectory(at: parent, withIntermediateDirectories: true)
            try data.write(to: writeURL, options: .atomic)
        }
    }

    public func createDirectory(at url: URL) throws {
        try coordinate(writingItemAt: url) { writeURL in
            try FileManager.default.createDirectory(at: writeURL, withIntermediateDirectories: true)
        }
    }

    public func removeItem(at url: URL) throws {
        try coordinate(writingItemAt: url) { writeURL in
            if FileManager.default.fileExists(atPath: writeURL.path) {
                try FileManager.default.removeItem(at: writeURL)
            }
        }
    }

    public func moveItem(from source: URL, to destination: URL) throws {
        #if canImport(Darwin)
        var coordinatorError: NSError?
        var moveError: Error?
        let coordinator = NSFileCoordinator(filePresenter: nil)
        coordinator.coordinate(
            movingItemAt: source,
            to: destination,
            error: &coordinatorError
        ) { newSource, newDestination in
            do {
                let parent = newDestination.deletingLastPathComponent()
                try FileManager.default.createDirectory(at: parent, withIntermediateDirectories: true)
                if FileManager.default.fileExists(atPath: newDestination.path) {
                    try FileManager.default.removeItem(at: newDestination)
                }
                try FileManager.default.moveItem(at: newSource, to: newDestination)
            } catch {
                moveError = error
            }
        }
        if let coordinatorError {
            throw LociError.coordinationFailed(coordinatorError.localizedDescription)
        }
        if let moveError {
            throw moveError
        }
        #else
        let parent = destination.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: parent, withIntermediateDirectories: true)
        if FileManager.default.fileExists(atPath: destination.path) {
            try FileManager.default.removeItem(at: destination)
        }
        try FileManager.default.moveItem(at: source, to: destination)
        #endif
    }

    public func fileExists(at url: URL) -> Bool {
        FileManager.default.fileExists(atPath: url.path)
    }

    // MARK: - Coordination primitives

    private func coordinate<T>(
        readingItemAt url: URL,
        body: (URL) throws -> T
    ) throws -> T {
        #if canImport(Darwin)
        var coordinatorError: NSError?
        var result: Result<T, Error>?
        let coordinator = NSFileCoordinator(filePresenter: nil)
        coordinator.coordinate(readingItemAt: url, error: &coordinatorError) { readURL in
            do {
                result = .success(try body(readURL))
            } catch {
                result = .failure(error)
            }
        }
        if let coordinatorError {
            throw LociError.coordinationFailed(coordinatorError.localizedDescription)
        }
        switch result {
        case .success(let value):
            return value
        case .failure(let error):
            throw error
        case .none:
            throw LociError.coordinationFailed("read coordination produced no result")
        }
        #else
        return try body(url)
        #endif
    }

    private func coordinate(
        writingItemAt url: URL,
        body: (URL) throws -> Void
    ) throws {
        #if canImport(Darwin)
        var coordinatorError: NSError?
        var writeError: Error?
        let coordinator = NSFileCoordinator(filePresenter: nil)
        coordinator.coordinate(writingItemAt: url, error: &coordinatorError) { writeURL in
            do {
                try body(writeURL)
            } catch {
                writeError = error
            }
        }
        if let coordinatorError {
            throw LociError.coordinationFailed(coordinatorError.localizedDescription)
        }
        if let writeError {
            throw writeError
        }
        #else
        try body(url)
        #endif
    }
}
