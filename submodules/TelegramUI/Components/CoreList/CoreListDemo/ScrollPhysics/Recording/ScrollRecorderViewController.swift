import UIKit

/// Hand-driven recorder: a tall plain UIScrollView whose real gesture is captured (via the
/// swizzler) into a GestureRecording and saved as JSON. Debug-only; not wired into the demo.
final class ScrollRecorderViewController: UIViewController {
    let scrollView = UIScrollView()
    private let sink = CaptureSink()
    private var displayLink: CADisplayLink?     // settle detector only — frames come from the swizzle
    private var recordingName: String?
    private var geometry: GestureRecording.Geometry?
    private var releaseTime: TimeInterval?
    private var released = false

    private let gestureNames = ["slow-drag-release", "medium-flick", "flick-into-bottom",
                                "overscroll-release", "creep", "reverse-mid-decel"]
    private let nameControl = UISegmentedControl(items: ["slow drag", "flick", "into edge",
                                                         "overscroll", "creep", "reverse"])
    private let inputKindControl = UISegmentedControl(items: ["Touch", "Trackpad"])
    private let statusLabel = UILabel()

    /// Fixture file/`name` for a scenario, prefixed when recorded via trackpad so touch and
    /// trackpad ground truth never collide in the Fixtures dir.
    static func fixtureName(scenario: String, trackpad: Bool) -> String {
        trackpad ? "trackpad-\(scenario)" : scenario
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground

        scrollView.frame = view.bounds
        scrollView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        scrollView.alwaysBounceVertical = true
        scrollView.contentInsetAdjustmentBehavior = .never   // clean zero-inset geometry for fixtures
        scrollView.contentSize = CGSize(width: view.bounds.width, height: 6000)
        let content = UILabel()
        content.numberOfLines = 0
        content.text = "Scroll recorder — pick a gesture, tap Record, then flick / drag."
        content.frame = CGRect(x: 16, y: 120, width: view.bounds.width - 32, height: 6000 - 140)
        scrollView.addSubview(content)
        // No delegate: ground truth is captured via the swizzle, not delegate callbacks.
        view.addSubview(scrollView)
        scrollView.panGestureRecognizer.addTarget(self, action: #selector(handlePan(_:)))

        installControlBar()
    }

    /// A floating Record/Stop bar pinned to the top — a sibling of the scroll view, so it does
    /// not intercept scroll drags. Debug-only.
    private func installControlBar() {
        nameControl.selectedSegmentIndex = 0
        inputKindControl.selectedSegmentIndex = 0

        let recordButton = UIButton(type: .system)
        recordButton.setTitle("● Record", for: .normal)
        recordButton.addTarget(self, action: #selector(recordTapped), for: .touchUpInside)

        let stopButton = UIButton(type: .system)
        stopButton.setTitle("■ Stop", for: .normal)
        stopButton.addTarget(self, action: #selector(stopTapped), for: .touchUpInside)

        statusLabel.text = "Idle"
        statusLabel.font = .preferredFont(forTextStyle: .footnote)
        statusLabel.adjustsFontSizeToFitWidth = true
        statusLabel.minimumScaleFactor = 0.6

        let buttons = UIStackView(arrangedSubviews: [recordButton, stopButton, statusLabel])
        buttons.axis = .horizontal
        buttons.spacing = 16
        buttons.alignment = .firstBaseline

        let bar = UIStackView(arrangedSubviews: [inputKindControl, nameControl, buttons])
        bar.axis = .vertical
        bar.spacing = 8
        bar.isLayoutMarginsRelativeArrangement = true
        bar.layoutMargins = UIEdgeInsets(top: 8, left: 12, bottom: 8, right: 12)
        bar.translatesAutoresizingMaskIntoConstraints = false

        let background = UIView()
        background.backgroundColor = UIColor.systemBackground.withAlphaComponent(0.92)
        background.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(background)
        view.addSubview(bar)
        NSLayoutConstraint.activate([
            bar.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            bar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            bar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            background.topAnchor.constraint(equalTo: view.topAnchor),
            background.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            background.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            background.bottomAnchor.constraint(equalTo: bar.bottomAnchor),
        ])
    }

    // MARK: Controls

    @objc private func recordTapped() {
        let scenario = gestureNames[nameControl.selectedSegmentIndex]
        let name = Self.fixtureName(scenario: scenario, trackpad: inputKindControl.selectedSegmentIndex == 1)
        // Deterministic start position (idle, BEFORE capture starts so it isn't recorded): so a single
        // gesture exercises the intended scenario regardless of where the previous one left off.
        let maxY = Swift.max(0, scrollView.contentSize.height - scrollView.bounds.height)
        let startY: CGFloat
        switch scenario {
        case "flick-into-bottom":  startY = Swift.max(0, maxY - 1000)  // room: one firm flick → edge + bounce
        case "overscroll-release": startY = maxY                       // at the bottom edge → drag up to overscroll
        case "reverse-mid-decel": startY = Swift.max(0, maxY / 2)  // room to scroll then reverse mid-momentum
        case "creep":             startY = 0                       // top → very slow creep
        default:                   startY = 0                          // top → drag / flick downward
        }
        scrollView.setContentOffset(CGPoint(x: 0, y: startY), animated: false)
        beginRecording(named: name)
        statusLabel.text = "● Recording: \(name)"
    }

    @objc private func stopTapped() { finishAndSave() }

    /// End the current recording (if any), save it, and reflect the result in the status label.
    private func finishAndSave() {
        guard recordingName != nil else { return }
        let rec = endRecording()
        let url = save(rec)
        statusLabel.text = url.map { "✓ \($0.lastPathComponent) (\(rec.frames.count) frames)" } ?? "Save failed"
    }

    // MARK: Recording lifecycle (also driven directly by tests)

    func beginRecording(named name: String) {
        sink.attach(to: scrollView)   // self-contained: installs swizzle hooks + sets the time baseline
        released = false
        releaseTime = nil
        recordingName = name
        geometry = GestureRecording.Geometry(
            contentWidth: scrollView.contentSize.width, contentHeight: scrollView.contentSize.height,
            boundsWidth: scrollView.bounds.width, boundsHeight: scrollView.bounds.height,
            insetTop: scrollView.adjustedContentInset.top, insetLeft: scrollView.adjustedContentInset.left,
            insetBottom: scrollView.adjustedContentInset.bottom, insetRight: scrollView.adjustedContentInset.right,
            scale: scrollView.traitCollection.displayScale == 0 ? 2 : scrollView.traitCollection.displayScale,
            decelerationRate: scrollView.decelerationRate.rawValue)
        displayLink?.invalidate()
        displayLink = CADisplayLink(target: self, selector: #selector(tick))
        displayLink?.add(to: .main, forMode: .common)
    }

    func endRecording() -> GestureRecording {
        displayLink?.invalidate(); displayLink = nil
        let zero = GestureRecording.Geometry(contentWidth: 0, contentHeight: 0, boundsWidth: 0, boundsHeight: 0,
                                             insetTop: 0, insetLeft: 0, insetBottom: 0, insetRight: 0,
                                             scale: 2, decelerationRate: 0.998)
        let rec = GestureRecording(name: recordingName ?? "empty", geometry: geometry ?? zero,
                                   frames: sink.frames, rubberBandSamples: sink.rubberBandSamples,
                                   touches: sink.touches, releaseTime: releaseTime)
        sink.detach()
        recordingName = nil; geometry = nil; releaseTime = nil
        return rec
    }

    /// Write a recording to the app Documents dir and print the path (for `simctl` retrieval).
    @discardableResult
    func save(_ rec: GestureRecording) -> URL? {
        guard let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else { return nil }
        let url = dir.appendingPathComponent("\(rec.name).json")
        let enc = JSONEncoder(); enc.outputFormatting = [.prettyPrinted, .sortedKeys]
        do { try enc.encode(rec).write(to: url); print("[ScrollRecorder] saved:", url.path); return url }
        catch { print("[ScrollRecorder] save failed:", error); return nil }
    }

    // MARK: Live capture

    @objc private func handlePan(_ gr: UIPanGestureRecognizer) {
        guard recordingName != nil, !released else { return }
        if gr.state == .ended || gr.state == .cancelled {
            released = true
            releaseTime = sink.elapsed()   // touch-up time → the deceleration clock baseline (analysis §2)
        }
    }

    /// Settle detector only: frames are event-sourced from the `setContentOffset:` swizzle, not here.
    @objc private func tick() {
        guard recordingName != nil else { return }
        if released && !scrollView.isDecelerating && !scrollView.isDragging {
            finishAndSave()
        }
    }
}
