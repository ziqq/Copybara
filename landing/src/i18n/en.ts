/* Copyright (c) 2026 Anton Ustinoff. Use and redistribution are subject to LICENSE. */
import type {Translation} from './types.ts';
/** English public product copy. */
const en: Translation = {
  label: 'English',
  meta: {
    index: {title: 'Copybara — clipboard history for Mac', description: 'A native clipboard manager for macOS. Search text, images and links, pin useful clips and paste with your keyboard. Your history stays on your Mac.'},
    privacy: {title: 'Privacy — Copybara', description: 'How Copybara stores clipboard history locally, uses Accessibility for pasting and checks for updates. Privacy information for the app and website.'},
  },
  nav: {label: 'Main navigation', language: 'Language', home: 'Home', privacy: 'Privacy', support: 'Support'},
  hero: {
    eyebrow: 'Native clipboard manager for macOS', title: 'Your clipboard history, all in one place.',
    lead: 'Your clipboard has more than one useful thing in it.',
    body: 'Copybara remembers text, images, formatted text and files. Open your history, search, and press Return to paste into the app you were using.',
    download: 'Download for Mac', guide: 'How it works', note: 'Free direct download · macOS 12 or later · No account required',
    alt: 'Copybara clipboard history with search, comments, an image, a file and a text snippet',
    caption: 'The real Copybara interface, shown with demonstration content. Appearance varies with macOS and your settings.',
  },
  features: {label: 'What you can do', items: [
    {title: 'Find the clip, keep your flow', text: 'Open history with ⌘⇧V. Search with fuzzy, exact or regular-expression matching, move with the arrow keys and paste with Return.'},
    {title: 'More than plain text', text: 'Keep text, images, rich text and file references. Pin useful entries, add searchable comments and paste without formatting when you need to.'},
    {title: 'Your history stays here', text: 'History is stored on your Mac. No account, cloud sync, advertising or analytics. Recognized password and transient clipboard types are filtered out.'},
  ]},
  steps: {title: 'From copy to paste in three steps', items: [
    {title: 'Copy as usual', text: 'Copybara sits in the menu bar and keeps eligible clipboard entries in a local history.'},
    {title: 'Press ⌘⇧V', text: 'Find an older clip with search or the arrow keys. Keep frequent clips pinned so they are easy to reach.'},
    {title: 'Press Return', text: 'Copybara brings you back to the previous app and pastes the selected clip. Allow Accessibility when prompted to enable automatic pasting.'},
  ]},
  pins: {title: 'Keep the useful things close.', text: 'Pin frequent clips, label them with comments and use the keyboard to bring them back. Reusable snippets keep the text you type again and again within reach.', alt: 'Copybara showing pinned demonstration clips and comments', caption: 'Pinned clips and comments in the real app, with demonstration content.'},
  gallery: {title: 'Your clipboard. Your settings.', text: 'Choose how much history to keep, your search mode, the popup position and where the app icon appears. Launch at login is optional on macOS 13 or later.', alt: 'Copybara preferences showing history retention, search mode and appearance controls', caption: 'Real Copybara preferences. Liquid Glass is available on macOS 26; earlier systems use the native material appearance.'},
  data: {eyebrow: 'Local by design', title: 'Your clipboard is not a cloud service.', paragraphs: ['Your history and snippets stay in local application storage. Copybara does not upload clipboard contents, use analytics or require a sign-in.', 'Accessibility is used to send the paste shortcut. Copybara does not use it to read screen contents. The direct-download build checks for updates through GitHub when you ask it to; updates are verified by Sparkle.'], link: 'Read the privacy policy'},
  support: {title: 'Need a hand?', text: 'Report a problem or suggest an improvement on GitHub. For a private support request, contact the developer by email.', issues: 'Open an issue', email: 'Email Anton', caution: 'Include your macOS and Copybara versions. Remove passwords and other private clipboard contents from logs and screenshots.'},
  policy: {title: 'Privacy policy', source: 'Policy source'}, footer: {developer: '© 2026 Anton Ustinoff. ', privacy: 'Privacy policy'},
};
export default en;
