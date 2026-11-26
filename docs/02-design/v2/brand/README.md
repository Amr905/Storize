# Storize

Storize saves the stories and posts of accounts you follow into your phone's gallery, quietly and automatically. The brand is warm, calm and plain-spoken: it works in the background and only asks for attention when something needs you.

## Brand at a glance

- **Name:** Storize, always one word with a capital S. Never "StoriZe" or "STORIZE" in running text.
- **Mark:** an ember rounded square holding a three-part *story ring* with a *save arrow* dropping through the open gap at the bottom. The ring stands for stories; the arrow stands for keeping them.
- **Colour:** Ember (`brand`) is the identity colour. Saffron (`accent`) marks what's new. Everything else is warm sand (light) or soft charcoal (dark) so photos and videos stay the focus.
- **Themes:** every screen ships in **Light** and **Dark**. The user picks System (default), Light or Dark in Settings → Appearance.

## Principles

1. **Calm by default.** The app works unattended. Ember appears only on the one action that matters on a screen; status uses quiet pills.
2. **Media first.** In the Library, Preview and viewers, content fills the screen. Chrome is thin; the viewers use `media-scrim` over black.
3. **Health is always visible.** Session and account status are never more than one glance away (status pills, the session banner).
4. **Honest about risk.** Warnings use plain words, never fear or dark patterns.

## Voice

- Short sentences, everyday words, second person: "Your stories are saved to the gallery."
- Say what happens and what to do: "Instagram asked us to slow down. We'll try again in 12 min."
- Buttons are verbs: *Save all*, *Check now*, *Add account*, *Log in again*. No "OK" when a verb fits.
- No exclamation marks, no emoji in UI text.

## Visual foundations

- **Colour tokens** (see Tokens): `surface` for the page, `surface-container` for cards and the nav bar, `surface-container-high` for inputs and skeletons. Text is `ink`; secondary text is `ink-muted`. One filled `brand` button per screen at most; secondary actions are tonal (`brand-container` + `on-brand-container`) or text buttons.
- **Status colours** only carry status: `success` active/saved, `warning` re-login, gaps or Instagram pause, `error` failures and destructive actions, `neutral-status` paused, not visible, or waiting to look up. Always pair colour with a label or icon.
- **New content:** a 2 px `brand` ring around a thumbnail and a saffron `accent` count ("3 new"). Highlights (pinned stories) carry a saffron "Highlight" badge on `accent-container`.
- **Type:** Roboto (the Android system face, nothing bundled). Headline 22/28 semibold for app bars, title 17/24 for usernames and section heads, body 15/22, label 13/18 medium, caption 12/16. Numbers in stat tiles use `numeral`.
- **Spacing:** a 4 px grid. Screen margins and card padding `space-4` (16 px); sections `space-6`; library grid gutters `space-2`.
- **Shape:** thumbnails `radius-thumb` (12), chips and inputs `radius-chip` (10), cards and sheet tops `radius-card` (20), buttons and pills `radius-pill`.
- **Elevation:** flat. Cards are tonal (`surface-container`) with no shadow; only the FAB and dialogs cast one.
- **Motion:** 200 ms standard easing; thumbnails open the viewers with a shared-element transition.

## Iconography

Material Symbols Rounded, 24 px, weight 400, `ink` or `ink-muted`. Filled variants only for the selected tab. Content badges on thumbnails: a play triangle + duration for video, a stacked-squares glyph + count for carousels, both on a `media-scrim` chip.

## Dark mode

Dark is not an inverted light theme: surfaces are soft charcoal (`#121214` → `#2A2A2E`) so photos don't glow against pure black, Ember lifts to `#FF8A5C` with dark text on it, and the logo switches to `storize-mark-dark.svg`. The story and post viewers are black in both themes.

## Logo use

- `assets/Logos/storize-mark.svg` on light grounds, `storize-mark-dark.svg` on dark grounds, `storize-wordmark.svg` for the welcome screen and store listing.
- App icon: the mark, full bleed (the launcher applies its own mask). Android 13+ themed icon: the ring and arrow as a single-colour glyph.
- Keep clear space of one ring-stroke width × 4 around the mark. Don't recolour it, stretch it or put it on photos.

## Screens

The mockups for every screen in both themes live in the "Storize — UI mockups" design canvas.
