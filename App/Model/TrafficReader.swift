//
//  SharedMemoryReader.swift
//  Xproxy
//
//  Created by lampman on 12/13/24.
//

import Foundation

class TrafficReader {
    static let shared = TrafficReader()
    private init() {}

    private var sentBytesPointer: UnsafeMutablePointer<UInt64>?
    private var recvBytesPointer: UnsafeMutablePointer<UInt64>?

    func setupSharedMemory() {
        let sentPath = FileManager.sharedSentPath
        let recvPath = FileManager.sharedRecvPath

        guard let sentFileDescriptor = openFileDescriptor(for: sentPath),
              let recvFileDescriptor = openFileDescriptor(for: recvPath) else {
            return
        }

        sentBytesPointer = mapMemory(fileDescriptor: sentFileDescriptor)
        recvBytesPointer = mapMemory(fileDescriptor: recvFileDescriptor)

        close(sentFileDescriptor)
        close(recvFileDescriptor)
    }

    func sentBytes() -> UInt64 {
        return sentBytesPointer?.pointee ?? 0
    }

    func recvBytes() -> UInt64 {
        return recvBytesPointer?.pointee ?? 0
    }

    private func openFileDescriptor(for path: String) -> Int32? {
        let fd = open(path, O_RDWR | O_CREAT, S_IRUSR | S_IWUSR)
        if fd < 0 {
            print("Failed to open file: \(path), errno: \(errno)")
            return nil
        }

        var fileStat = stat()
        if fstat(fd, &fileStat) == 0 {
            if (fileStat.st_mode & S_IFMT) != S_IFREG {
                print("Path does not point to a regular file.")
                close(fd)
                return nil
            }
        }

        if ftruncate(fd, off_t(MemoryLayout<UInt64>.size)) == -1 {
            print("Failed to set file size for: \(path), errno: \(errno)")
            close(fd)
            return nil
        }
        return fd
    }

    private func mapMemory(fileDescriptor: Int32) -> UnsafeMutablePointer<UInt64>? {
        let size = MemoryLayout<UInt64>.size
        let pointer = mmap(nil, size, PROT_READ, MAP_SHARED, fileDescriptor, 0)
        if pointer == MAP_FAILED {
            print("mmap failed: errno: \(errno)")
            return nil
        }
        return pointer?.assumingMemoryBound(to: UInt64.self)
    }
}
