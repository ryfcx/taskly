# Taskly

Gamified task app for iOS. Clear daily quests for XP, run focus sessions for coins, spend coins on rewards you define.

SwiftUI + SwiftData. Everything stays on device.

## Tabs

- **Today** — today's board. Switch to tomorrow to plan ahead.
- **Focus** — timed sessions. Coins/XP every 5 minutes focused. Pause doesn't count.
- **Stats** — XP history, categories, consistency.
- **Profile** — notifications, manage/archive quests, reset.

## Quests

Daily, weekly, or one-off. Categories + difficulty set the XP (Trivial → Ultra). Ultra is for stuff that eats most of the day. Optional reminders. Can start today, tomorrow, or a custom date. Long-press a quest to skip it for today. Drag the grip on today/tomorrow to reorder.

## Coins & XP

- Quests pay XP (streaks add a bit) and a small coin cut
- Focus pays better: 1 coin + 2 XP per 5 min
- Level curve starts at 100 XP, +45 per level after
- Rewards are priced by you (starter pack available)

## Notifications

Morning briefing, evening nudge, mid-day encouragement, streak warning. Also warns when a free Apple developer build is about to expire (7 days).

## Breaks

Profile → Set a break. Pick start/end dates — board stays empty, pings stay off, streaks pause instead of resetting.

## Run

Open `Taskly.xcodeproj` in Xcode and hit Run. Targets iOS 26.

```
Taskly/
  Models/   Views/   Services/   Theme/
```
