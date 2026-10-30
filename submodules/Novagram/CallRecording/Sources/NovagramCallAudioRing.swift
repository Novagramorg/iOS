import Foundation
import os

// Hands PCM from the call's real-time audio thread to the recorder queue.
// One ring per source (microphone, playout), so each ring has exactly one producer and one consumer.
// The producer never waits: it only try-locks, and drops the chunk when the lock is taken or the ring is full.
// All memory is allocated up front; the producer path does no allocation, no ObjC messaging and no logging.
final class NovagramCallAudioRing {
    struct Chunk {
        let samples: UnsafePointer<Int16>
        let frames: Int
        let channels: Int
        let sampleRate: UInt32
        let hostTime: UInt64
    }

    private struct SlotInfo {
        var frames: Int = 0
        var channels: Int = 0
        var sampleRate: UInt32 = 0
        var hostTime: UInt64 = 0
    }

    static let defaultSlotCount = 128
    // 2048 values hold 20 ms of 48 kHz stereo; larger chunks are split over several slots.
    static let defaultSlotCapacity = 2048
    static let maxChannels = 8

    let slotCount: Int
    let slotCapacity: Int

    private let lock: UnsafeMutablePointer<os_unfair_lock>
    private let storage: UnsafeMutablePointer<Int16>
    private let slots: UnsafeMutablePointer<SlotInfo>
    // Guarded by `lock`. They only grow; the slot index is the value modulo `slotCount`.
    private var writeIndex: Int = 0
    private var readIndex: Int = 0
    private var droppedChunkCount: Int = 0

    init(slotCount: Int = NovagramCallAudioRing.defaultSlotCount, slotCapacity: Int = NovagramCallAudioRing.defaultSlotCapacity) {
        self.slotCount = slotCount
        self.slotCapacity = slotCapacity
        self.lock = UnsafeMutablePointer<os_unfair_lock>.allocate(capacity: 1)
        self.lock.initialize(to: os_unfair_lock())
        self.storage = UnsafeMutablePointer<Int16>.allocate(capacity: slotCount * slotCapacity)
        self.storage.initialize(repeating: 0, count: slotCount * slotCapacity)
        self.slots = UnsafeMutablePointer<SlotInfo>.allocate(capacity: slotCount)
        self.slots.initialize(repeating: SlotInfo(), count: slotCount)
    }

    deinit {
        self.slots.deinitialize(count: self.slotCount)
        self.slots.deallocate()
        self.storage.deinitialize(count: self.slotCount * self.slotCapacity)
        self.storage.deallocate()
        self.lock.deinitialize(count: 1)
        self.lock.deallocate()
    }

    // Real-time thread. Copies the interleaved samples and returns at once.
    func write(_ samples: UnsafePointer<Int16>, frames: Int, channels: Int, sampleRate: UInt32, hostTime: UInt64) {
        guard frames > 0, channels > 0, channels <= NovagramCallAudioRing.maxChannels, sampleRate > 0 else {
            return
        }
        let framesPerSlot = self.slotCapacity / channels
        guard framesPerSlot > 0, os_unfair_lock_trylock(self.lock) else {
            return
        }
        var offset = 0
        while offset < frames {
            if self.writeIndex - self.readIndex >= self.slotCount {
                self.droppedChunkCount += 1
                break
            }
            let count = min(framesPerSlot, frames - offset)
            let slot = self.writeIndex % self.slotCount
            (self.storage + slot * self.slotCapacity).update(from: samples + offset * channels, count: count * channels)
            self.slots[slot] = SlotInfo(frames: count, channels: channels, sampleRate: sampleRate, hostTime: hostTime)
            self.writeIndex += 1
            offset += count
        }
        os_unfair_lock_unlock(self.lock)
    }

    // Recorder queue only. Hands every chunk written so far to `body`, oldest first, then frees their slots.
    // The slots are read outside the lock: the producer never touches a slot between readIndex and writeIndex.
    func consume(_ body: (Chunk) -> Void) {
        os_unfair_lock_lock(self.lock)
        let start = self.readIndex
        let end = self.writeIndex
        os_unfair_lock_unlock(self.lock)
        guard end > start else {
            return
        }
        for index in start ..< end {
            let slot = index % self.slotCount
            let info = self.slots[slot]
            body(Chunk(samples: UnsafePointer(self.storage + slot * self.slotCapacity), frames: info.frames, channels: info.channels, sampleRate: info.sampleRate, hostTime: info.hostTime))
        }
        os_unfair_lock_lock(self.lock)
        self.readIndex = end
        os_unfair_lock_unlock(self.lock)
    }

    var droppedChunks: Int {
        os_unfair_lock_lock(self.lock)
        let value = self.droppedChunkCount
        os_unfair_lock_unlock(self.lock)
        return value
    }
}

enum NovagramCallHostClock {
    private static let timebase: mach_timebase_info_data_t = {
        var info = mach_timebase_info_data_t()
        mach_timebase_info(&info)
        return info
    }()

    static func now() -> UInt64 {
        return mach_absolute_time()
    }

    static func seconds(_ hostTime: UInt64) -> Double {
        let info = NovagramCallHostClock.timebase
        return Double(hostTime) * Double(info.numer) / Double(info.denom) / 1_000_000_000.0
    }
}
