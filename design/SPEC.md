# RadarShield client — UI spec (designer handoff 2026-06-05)

Source prototype: `design/prototype/` (React board, run via `RadarShield Client.html`).
This doc is the Flutter implementation contract derived from it.

## Core idea
Radical simplicity: **one big button on the whole screen** — "нажал → работает".
Connection status is read by button **colour**. Everything technical is hidden
behind simple secondary screens.

> ⚠️ Updated 2026-06-05: the prototype's "advanced mode" opened the raw FlClash UI.
> That was reverted — we do NOT show FlClash's interface at all. Every feature a
> user might need is redrawn in our style. The own "advanced" screens to design
> (server picker, connection details, diagnostics, split-tunnel, extra settings
> toggles) and what we deliberately drop are specified in `design/BRIEF-advanced.md`
> (handed back to the designer).

## Design tokens (from `frame.jsx`)
Dark navy theme.
| token | value | use |
|-------|-------|-----|
| navy | `#0d1b2a` | screen bg |
| navy2 | `#0b1622` | titlebar bg (Windows) |
| panel | `#12243a` | cards, chips, corner buttons |
| panel2 | `#16304d` | setting-row icon bg |
| line | `rgba(255,255,255,0.08)` | hairline borders |
| line2 | `rgba(255,255,255,0.14)` | input border |
| ink | `#eef3f9` | primary text |
| dim | `#b7c4d3` | secondary text |
| mute | `#7f8fa3` | tertiary text |
| amber | `#ffb703` | brand accent, CTA buttons |
| **off** | `#7c8ba0` | button: disconnected (grey) |
| **connecting** | `#ffb703` | button: connecting (amber/yellow) |
| **connected** | `#2fc98a` | button: connected (green) |
| **error** | `#f4736b` | button: error (red) |

Fonts: body `Inter`, display/headings `Manrope`. Both need bundling as assets
(fallback to system sans until added). Logo: shield outline + amber "R" (`RSLogo`
in `frame.jsx`) — replace with the designer's real logo/icon when delivered.

## Power button (centerpiece — `PowerButton` in `screens.jsx`)
Default style `radar`. Circular. Colour morphs over ~600ms between states.
| state | word | sub | icon | extras |
|-------|------|-----|------|--------|
| off | Пуск | Нажмите, чтобы подключиться | power | grey |
| connecting | Подключаюсь… | Устанавливаем защищённое соединение | power | spinner arc + sonar rings |
| connected | Подкл��чено | Соединение защищено | shield-check | breathe + sonar rings |
| error | Не получилось | Нажмите ещё раз | alert | red |

Tap behaviour: off/error → connecting → (real core result) → connected; tap while
connected → off; tap while connecting → cancel → off. Radar style = expanding
sonar rings while connecting/connected. (Other styles glow/minimal exist in
prototype tweaks but `radar` is the chosen default.)

## Screens
- **Splash** — logo + radar rings + pulsing dots. Show during app/core init.
- **Onboarding** — paste subscription link from TG bot → `addProfileFormURL`.
  Big amber "Продолжить" enabled once a link is present. "Открыть Telegram-бота"
  link. (Phase 2: login by email/Telegram code instead of paste.)
- **Main** — brand top-left, corner menu top-right (logout + gear), centered power
  button + status text, optional location chip ("Россия · авто"), optional shield
  pill, optional session timer (connected only).
- **Settings** — account card (sub status/expiry/quota + "Продлить"), list:
  Продвинутый режим (→ FlClash UI), Локация, Автоподключение (toggle), Язык,
  О приложении; danger "Выйти из аккаунта".
- **Expired** — clock graphic, "Подписка закончилась", amber "Продлить подписку"
  (→ TG bot payment).
- **Advanced** — the existing FlClash navigation (dashboard/proxies/profiles/
  routes/logs). Reached from Settings → "Продвинутый режим".

## FlClash integration points
- Theme: force dark + navy palette (`lib/...` theme/color providers).
- Connection state + start/stop: wire button to the real core lifecycle
  (`CoreAction` / run-state in `lib/providers/`). Button colour ← actual VPN
  status, not a local timer.
- Home: replace FlClash's default landing tab with `MainScreen`; keep the full
  FlClash nav mounted but reachable only via Settings → Продвинутый режим.
- Onboarding gate: if no profiles → Onboarding (paste URL). Zero-config: a
  build-time `--dart-define=DEFAULT_SUB_URL=...` can pre-fill/auto-import so the
  user skips even the paste (test sub already provisioned server-side).
- Logout: clear active profile/subscription, return to Onboarding.

## Phases
1. Theme + `PowerButton` + `MainScreen` wired to real connect/disconnect, set as
   home. (centerpiece)
2. Onboarding (paste link) + first-run gate + logout.
3. Settings + Expired + "Продвинутый режим" → existing FlClash UI.
4. Splash, session timer, location chip, fonts, real logo/icons from designer.
5. Windows compact-window parity.

Each phase: implement → push → CI builds APK (`radarshield-android.yaml`) →
visual check on device → iterate.
