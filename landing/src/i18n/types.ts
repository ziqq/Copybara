/* Copyright (c) 2026 Anton Ustinoff. Use and redistribution are subject to LICENSE. */
/** Localized heading and body for a feature or setup step. */
export interface TextItem {title: string; text: string;}
/** Complete EN/RU website copy. */
export interface Translation {
  label: string;
  meta: {index: {title: string; description: string}; privacy: {title: string; description: string}};
  nav: {label: string; language: string; home: string; privacy: string; support: string};
  hero: {eyebrow: string; title: string; lead: string; body: string; download: string; guide: string; note: string; alt: string; caption: string};
  features: {label: string; items: TextItem[]};
  steps: {title: string; items: TextItem[]};
  pins: {title: string; text: string; alt: string; caption: string};
  gallery: {title: string; text: string; alt: string; caption: string};
  data: {eyebrow: string; title: string; paragraphs: string[]; link: string};
  support: {title: string; text: string; issues: string; email: string; caution: string};
  policy: {title: string; source: string};
  footer: {developer: string; privacy: string};
}
