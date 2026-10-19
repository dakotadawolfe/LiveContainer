import Foundation
import Darwin

enum ContainerBundleCommit {
    static func install(prepared: URL, destination: URL) throws {
        if FileManager.default.fileExists(atPath: destination.path) {
            // Keep the installed path valid even if the process terminates during replacement.
            let result = prepared.path.withCString { source in
                destination.path.withCString { target in
                    renameatx_np(AT_FDCWD, source, AT_FDCWD, target, UInt32(RENAME_SWAP))
                }
            }
            guard result == 0 else { throw NSError(domain: NSPOSIXErrorDomain, code: Int(errno)) }
            // The old bundle now occupies prepared and is removed with the staging workspace.
        } else {
            try FileManager.default.moveItem(at: prepared, to: destination)
        }
    }
}
