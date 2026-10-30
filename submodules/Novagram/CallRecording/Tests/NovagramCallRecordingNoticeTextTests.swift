import XCTest
import NovagramLocalization

final class NovagramCallRecordingNoticeTextTests: XCTestCase {
    func testNoticeFollowsTheAppLanguage() {
        XCTAssertEqual(NovagramL10n(languageCode: "en").callRecording_noticeMessage, "🔴 I'm recording this call (Novagram)")
        XCTAssertEqual(NovagramL10n(languageCode: "uz").callRecording_noticeMessage, "🔴 Men bu qo'ng'iroqni yozib olyapman (Novagram)")
        XCTAssertEqual(NovagramL10n(languageCode: "ru").callRecording_noticeMessage, "🔴 Я записываю этот звонок (Novagram)")
        XCTAssertEqual(NovagramL10n(languageCode: "zh-hans-raw").callRecording_noticeMessage, "🔴 我正在录制这次通话（Novagram）")
        // Any other language gets the English text.
        XCTAssertEqual(NovagramL10n(languageCode: "de").callRecording_noticeMessage, "🔴 I'm recording this call (Novagram)")
    }
}
