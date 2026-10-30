import Foundation

// Mixes the call's two audio streams into one 48 kHz stereo Int16 timeline.
// The playout stream (the other side plus the call tones) is the master clock: every playout chunk produces output
// frames, and the same number of microphone frames is popped from a FIFO (zeros on underrun). Both streams are
// downmixed to mono and resampled to 48 kHz first; the mono mix is written to both channels.
// Used on the recorder's serial queue only.
final class NovagramCallAudioMixer {
    static let outputSampleRate: Int = 48000
    static let outputChannels: Int = 2
    // The microphone may run at most this far ahead of the playout clock; older samples are dropped beyond it.
    static let defaultMaxMicLeadFrames = NovagramCallAudioMixer.outputSampleRate / 2

    private let micResampler = NovagramCallLinearResampler()
    private let playoutResampler = NovagramCallLinearResampler()
    private let micFifo: NovagramCallFloatFifo
    private var scratch: [Float] = []

    init(maxMicLeadFrames: Int = NovagramCallAudioMixer.defaultMaxMicLeadFrames) {
        self.micFifo = NovagramCallFloatFifo(capacity: max(maxMicLeadFrames, 1))
    }

    var bufferedMicFrames: Int {
        return self.micFifo.count
    }

    // While muted the microphone still advances, with silence, so it stays in step with the playout clock.
    func pushMic(_ samples: UnsafePointer<Int16>, frames: Int, channels: Int, sampleRate: UInt32, isMuted: Bool) {
        guard frames > 0, channels > 0, sampleRate > 0 else {
            return
        }
        let fifo = self.micFifo
        self.micResampler.process(samples, frames: frames, channels: channels, sampleRate: Int(sampleRate), scratch: &self.scratch) { value in
            fifo.push(isMuted ? 0 : value)
        }
    }

    // Drops the oldest microphone frames (captured before the recording's time zero).
    func discardMic(frames: Int) {
        var remaining = min(max(frames, 0), self.micFifo.count)
        while remaining > 0 {
            _ = self.micFifo.pop()
            remaining -= 1
        }
    }

    // Appends the mixed interleaved stereo frames to `output`; returns how many frames were appended.
    @discardableResult
    func mixPlayout(_ samples: UnsafePointer<Int16>, frames: Int, channels: Int, sampleRate: UInt32, output: inout [Int16]) -> Int {
        guard frames > 0, channels > 0, sampleRate > 0 else {
            return 0
        }
        let start = output.count
        let fifo = self.micFifo
        self.playoutResampler.process(samples, frames: frames, channels: channels, sampleRate: Int(sampleRate), scratch: &self.scratch) { value in
            let mixed = NovagramCallAudioMixer.clip(value + fifo.pop())
            output.append(mixed)
            output.append(mixed)
        }
        return (output.count - start) / NovagramCallAudioMixer.outputChannels
    }

    // Fills a gap in the playout clock (playout stalled or chunks dropped): the microphone alone, zeros on underrun.
    @discardableResult
    func mixSilence(frames: Int, output: inout [Int16]) -> Int {
        guard frames > 0 else {
            return 0
        }
        output.reserveCapacity(output.count + frames * NovagramCallAudioMixer.outputChannels)
        for _ in 0 ..< frames {
            let mixed = NovagramCallAudioMixer.clip(self.micFifo.pop())
            output.append(mixed)
            output.append(mixed)
        }
        return frames
    }

    static func clip(_ value: Float) -> Int16 {
        let rounded = value.rounded()
        if rounded >= Float(Int16.max) {
            return Int16.max
        }
        if rounded <= Float(Int16.min) {
            return Int16.min
        }
        return Int16(rounded)
    }
}

// Streaming linear-interpolation resampler to 48 kHz. Positions are kept as exact integers in units of
// 1 / 48000 of an input sample, so it never drifts and 48 kHz input passes through unchanged.
final class NovagramCallLinearResampler {
    private let outputRate = NovagramCallAudioMixer.outputSampleRate
    // Position of the next output sample in input samples times `outputRate`; -outputRate is the previous chunk's
    // last sample.
    private var position: Int = 0
    private var previous: Float = 0
    private var inputRate: Int = 0

    func process(_ samples: UnsafePointer<Int16>, frames: Int, channels: Int, sampleRate: Int, scratch: inout [Float], emit: (Float) -> Void) {
        if sampleRate != self.inputRate {
            self.inputRate = sampleRate
            self.position = 0
        }
        if scratch.count < frames {
            scratch = [Float](repeating: 0, count: frames)
        }
        let scale = 1.0 / Float(channels)
        for frame in 0 ..< frames {
            var sum: Float = 0
            let base = frame * channels
            for channel in 0 ..< channels {
                sum += Float(samples[base + channel])
            }
            scratch[frame] = channels == 1 ? sum : sum * scale
        }
        if sampleRate == self.outputRate {
            for frame in 0 ..< frames {
                emit(scratch[frame])
            }
            self.previous = scratch[frames - 1]
            return
        }
        let limit = (frames - 1) * self.outputRate
        while self.position <= limit {
            let index = self.position >= 0 ? self.position / self.outputRate : -1
            let remainder = self.position - index * self.outputRate
            let first = index >= 0 ? scratch[index] : self.previous
            if remainder == 0 {
                emit(first)
            } else {
                let second = scratch[index + 1]
                emit(first + (second - first) * Float(remainder) / Float(self.outputRate))
            }
            self.position += sampleRate
        }
        self.position -= frames * self.outputRate
        self.previous = scratch[frames - 1]
    }
}

// Fixed-capacity FIFO of mono samples. On overflow the oldest samples are dropped, so the microphone never lags
// the playout clock by more than the capacity.
final class NovagramCallFloatFifo {
    private var buffer: [Float]
    private var head = 0
    private(set) var count = 0

    init(capacity: Int) {
        self.buffer = [Float](repeating: 0, count: capacity)
    }

    func push(_ value: Float) {
        let capacity = self.buffer.count
        if self.count == capacity {
            self.head = (self.head + 1) % capacity
            self.count -= 1
        }
        self.buffer[(self.head + self.count) % capacity] = value
        self.count += 1
    }

    func pop() -> Float {
        guard self.count > 0 else {
            return 0
        }
        let value = self.buffer[self.head]
        self.head = (self.head + 1) % self.buffer.count
        self.count -= 1
        return value
    }
}
