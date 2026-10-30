#ifndef NOVAGRAM_VIDEO_SINK_FANOUT_H
#define NOVAGRAM_VIDEO_SINK_FANOUT_H

// Novagram (HOOKS.md, "Call recording"): one video source, several outputs.
// The 1:1 camera capturer (`setOutput`) and the incoming video (`setIncomingVideoOutput`) take a single sink, so a
// second subscriber (call recording) used to replace the call screen's own sink and froze its picture. This sink is
// set once and hands every frame to all added outputs.

#include <map>
#include <memory>
#include <mutex>
#include <vector>

#include "api/video/video_frame.h"
#include "api/video/video_sink_interface.h"

class NovagramVideoSinkFanout : public rtc::VideoSinkInterface<webrtc::VideoFrame> {
public:
    void OnFrame(const webrtc::VideoFrame &frame) override {
        // Copy the list so an output can be added or removed while a frame is delivered.
        std::vector<std::shared_ptr<rtc::VideoSinkInterface<webrtc::VideoFrame>>> sinks;
        {
            std::lock_guard<std::mutex> lock(_mutex);
            sinks.reserve(_sinks.size());
            for (const auto &it : _sinks) {
                sinks.push_back(it.second);
            }
        }
        for (const auto &sink : sinks) {
            sink->OnFrame(frame);
        }
    }

    void add(int sinkId, std::shared_ptr<rtc::VideoSinkInterface<webrtc::VideoFrame>> sink) {
        std::lock_guard<std::mutex> lock(_mutex);
        _sinks[sinkId] = sink;
    }

    void remove(int sinkId) {
        std::lock_guard<std::mutex> lock(_mutex);
        _sinks.erase(sinkId);
    }

private:
    std::mutex _mutex;
    std::map<int, std::shared_ptr<rtc::VideoSinkInterface<webrtc::VideoFrame>>> _sinks;
};

#endif
