# Anchor

An open-source, 3D-printable focus puck. Tap a physical NFC tag to unlock your
phone's screen-time block — no tag, no unlock.

Software blockers share a failure mode: they're trivially bypassed. You uninstall
the app, flip a switch in Settings, or wait out a timer. The friction is digital,
and digital friction is cheap to defeat the moment you actually want to break your
own rule.

Anchor moves the friction into the physical world. A passive NFC tag lives in a
printed housing you leave somewhere inconvenient — another room, a drawer, your
desk at work. Unlocking means physically going and getting it. That retrieval is
the whole mechanism, and it can't be clicked past.

Commercial versions of this idea exist and cost about $60. Anchor's tag costs
under a dollar, the housing is parametric and printable, and the whole thing is
yours to modify.

## How it works

1. **Pair** — scan a tag once. Anchor stores its factory-burned UID.
2. **Choose** — pick the apps, categories, and sites to block.
3. **Focus** — Anchor applies a system-level shield, either on demand or on a
   daily schedule. Blocked apps show a custom screen telling you to go find the
   puck.
4. **Unlock** — scan the same tag. The UID must match, or nothing lifts.

The block is enforced by iOS, not by Anchor. Once applied, it survives force
quits and reboots.

## What this does and doesn't protect against

Anchor raises friction. It does not make evasion impossible, and any project in
this category claiming otherwise is overselling.

**Closed:**

- *Deleting the app.* Anchor sets `denyAppRemoval` while a session is active, so
  iOS refuses to uninstall it. Without this the block would die with the app.
- *Guessing or faking a tap.* Unlocking requires the paired UID, not just any tag.

**Open, by design or by platform limit:**

- *Revoking Screen Time access in Settings* lifts everything instantly. There is
  no API-level defense. The only real fix is a Screen Time passcode held by
  someone else, which is a different product.
- *Cloning the tag.* A passive tag's UID is readable by any phone and writable to
  a "magic" NTAG clone for a couple of dollars. This is fine for the actual threat
  model — deterring yourself — but it is not tamper-proof. Tags with real
  cryptographic authentication (NTAG 424 DNA) cost about the same and would close
  this if it ever matters.
- *Waiting out a scheduled session.* A scheduled window ends on its own; the puck
  is for unlocking early. See "Design decisions" below.

## Requirements

- **A paid Apple Developer Program membership.** Both NFC tag reading and Family
  Controls need entitlements a free personal team can't provision. This is the
  most common reason a build fails to install.
- **Xcode 16 or later.** The project uses filesystem-synchronized groups.
- **A real iPhone running iOS 17+.** NFC and Screen Time don't work in the
  Simulator, so there is nothing useful to test there.
- **An NFC tag.** NTAG213/215/216 stickers or discs, roughly $0.30–$1 each.

## Building

1. Open `Anchor.xcodeproj`.
2. Set your team on all three targets: `Anchor`, `AnchorShield`, `AnchorMonitor`.
3. Replace the placeholder bundle identifiers. They must stay in a parent/child
   relationship:
   - `com.example.Anchor`
   - `com.example.Anchor.AnchorShield`
   - `com.example.Anchor.AnchorMonitor`
4. Replace the placeholder app group `group.com.example.Anchor` in **all three**
   `.entitlements` files and in `Shared/AnchorStore.swift`. These must match
   exactly — a mismatch fails silently, with the app and its extensions reading
   different containers and no error anywhere.
5. Register the app group and bundle IDs in your developer account.
6. Build to a physical device.

## Layout

```
Anchor/           the app — NFC reader, UI, session control
AnchorShield/     ShieldConfiguration extension — the block screen
AnchorMonitor/    DeviceActivityMonitor extension — scheduled sessions
Shared/           app-group state and shield control, compiled into
                  both the app and the monitor
hardware/         printable enclosure
```

`Shared/` is one folder listed in two targets. The app and the monitor run in
separate processes and must agree on what "blocked" means, so the logic lives in
exactly one place.

## Hardware

A passive NFC tag in a two-piece snap-fit housing.

| Part | Notes |
| --- | --- |
| NFC tag | NTAG213/215/216, 25 mm disc or sticker |
| Filament | Any. PLA is fine; the part carries no load |
| Print | ~0.2 mm layers, 20% infill, no supports |

Do not put the tag behind metal, and don't embed it in a part you print *around* —
NFC needs a clear path to the phone, and printing over a tag risks heat damage.
Drop it in after printing and snap the lid on.

See `hardware/` for the parametric source and its current status.

## Design decisions

**A scheduled session ends on its own.** The puck unlocks *early*; it isn't
required to end a window you already chose. The stricter alternative — only the
puck ever lifts a block — is truer to the premise, but a schedule firing while the
puck is across town would lock the phone with no way out. Flipping this is one
line in `AnchorMonitor/DeviceActivityMonitorExtension.swift`.

**Schedule end clears everything**, including a manual session started inside that
window. Both go through the same store, so the monitor can't tell them apart.

**The shield can't hand off.** Its button cannot launch Anchor or start a scan —
iOS gives extensions no such capability, and even a full `ShieldActionExtension`
only returns `.close`, `.defer`, or `.none`. The shield instructs; you open Anchor
yourself.

## Status

The full loop is implemented and builds clean. It has not yet been verified on
physical hardware — that's the next milestone, and it's gated on the developer
account above.

## License

MIT. See [LICENSE](LICENSE).
