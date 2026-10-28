# Upstream 12.8 integratsiya — holat fayli (2026-07-06)

Telegram-iOS fork'ni upstream 12.7.8 -> 12.8 ga ko'tarish. Hooks + Fenixuz features saqlanishi shart.

## Kalit SHA'lar
- `main` HEAD (fork, 12.7.8):      b47b8c4546   <- MUZLAYDI, tegilmaydi
- Safety tag:                      pre-12.8-merge-2026-07-06 (= b47b8c4546)
- Bizning oxirgi integratsiya bazasi (upstream May1): 03f60bd391  <- REPLAY BASE
- upstream/master (12.8, Jun5):    6e370e06d1   <- NISHON (theirs)
- Ish branch:                      merge/upstream-12.8 (worktree, upstream/master dan)
- Worktree path:                   /Users/codingtech/Documents/Telegram-iOS-12.8-merge

## Strategiya: REPLAY (merge emas!)
Upstream tarixni qayta yozgan (merge-base 2019). To'g'ridan merge = conflict bo'roni.
Shuning uchun: toza upstream/master dan boshlab, `git diff 03f60bd391 HEAD` ni ustiga
`git apply --3way` bilan qo'yamiz. Conflict faqat 32 haqiqiy fayzda.

## Fazalar
- [x] 1. Worktree yaratildi (branch merge/upstream-12.8 @ upstream 12.8)
- [x] 2. Fenixuz modullari (20 modul) + vosk — main'dan olindi
- [x] 3. Hooks: 267 non-overlap main'dan + 14 conflict qo'lda hал (64 auto-merge)
- [x] 4. Config: versions.json=12.8, BUILD union-merge, CLAUDE.md=ours, tgcalls=upstream
- [x] 8. Hook verify: 20 modul + Apple-critical (demo fetcher 3 sayt, IAP gate 4 sayt) OK
- [x] COMMIT: 5a48158336 "merged telegram 12.8 upstream keeping our hooks and features" (422 fayl)
- [~] 7. Build (background bzsj77nuv): submodule init + ./run.sh — DEVOM ETMOQDA
- [ ] 9. Feature test (build'dan keyin)
- [ ] 10. main'ga fast-forward (faqat build yashil bo'lsa)

## 14 conflict qanday hал qilindi
- union (ikkala): .gitignore, AuthorizationUI/BUILD, ChatTextInputPanelNode/BUILD, ChatListController imports
- custom: prebuilt_watchos_build.sh (ours --norsrc), SharedWakeupManager (upstream hasBackgroundLocationTask + our fenixuzPinned)
- take-upstream (sof API drift, Fenixuz hook yo'q, auto-merge saqlangan): ChatContextMenus, PeerInfoScreen, PerformButtonAction, ChatController(21), SharedAccountContext(6), ChatTextInputPanelNode(7), ChatHistoryListNode(14)
- re-inject: ChatControllerNode — Pro Messager (auto-text + text-style) upstream 12.8 loop ustiga qayta qo'yildi

## 32 CONFLICT ZONE fayllari
scratchpad/true_conflict_zone.txt da. Apple-critical bo'lganlari:
- submodules/AuthorizationUI/Sources/AuthorizationSequenceController.swift (demo fetcher)
- submodules/TelegramUI/Sources/OpenResolvedUrl.swift (IAP gate deep-link)
- submodules/WebUI/Sources/WebAppController.swift (IAP gate web app)
- submodules/TelegramUI/Sources/ChatController.swift (IAP gate bot invoice)
- submodules/TelegramUI/Sources/AppDelegate.swift (isAppStoreBuild flag)

## Undo
Xato bo'lsa: worktree'ni o'chirish `git worktree remove --force ...`, branch `git branch -D merge/upstream-12.8`.
main hech qachon tegilmaydi. `git checkout pre-12.8-merge-2026-07-06` = to'liq qaytish.
