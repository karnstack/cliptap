/**
 * HTML/CSS recreation of the Cliptap window (Sources/Views.swift).
 * Sizes follow the SwiftUI layout: 780×500 window, 52pt search bar,
 * 320pt list, 36pt rows and footer. All lengths scale with --u in styles.css.
 */

type Clip =
  | { kind: "text"; text: string }
  | { kind: "image"; text: string };

const pinned: Clip[] = [
  { kind: "text", text: "ssh deploy@staging.example.com" },
  { kind: "text", text: "Looks good to me. Merging after CI passes." },
];

const SELECTED_TEXT =
  "Release notes for 1.2:\nSearch now matches text inside links.\nPinned items stay on top after a restart, and copied images keep their full size.";

const recent: Clip[] = [
  { kind: "text", text: SELECTED_TEXT },
  { kind: "text", text: "https://developer.apple.com/documentation/appkit/nspasteboard" },
  { kind: "text", text: "#0DC37D" },
  { kind: "image", text: "Image 1280×800" },
  { kind: "text", text: "pnpm install --frozen-lockfile" },
  { kind: "text", text: "Meeting moved to Thursday, 3:30 pm" },
  { kind: "text", text: "font-variant-numeric: tabular-nums;" },
];

const SELECTED_INDEX = 2; // first "Recent" row, shortcut ⌘3

const oneLine = (s: string) =>
  s
    .split("\n")
    .map((l) => l.trim())
    .filter(Boolean)
    .join(" ");

export function AppMock() {
  let n = 0;
  const row = (clip: Clip) => {
    const i = n++;
    return (
      <li key={i} className="m-row" data-selected={i === SELECTED_INDEX || undefined}>
        <span className="m-thumb">{clip.kind === "image" ? <Thumbnail /> : <TextIcon />}</span>
        <span className="m-row-text">{oneLine(clip.text)}</span>
        <span className="m-row-key">⌘{i + 1}</span>
      </li>
    );
  };

  return (
    <div
      className="m-window"
      role="img"
      aria-label="The Cliptap window: a search field, a list of pinned and recent clipboard items with ⌘1 to ⌘9 shortcuts, a preview of the selected item, and keyboard hints at the bottom."
    >
      <div className="m-search">
        <SearchIcon />
        <span className="m-search-placeholder">Search clipboard history</span>
        <span className="m-count">42 items</span>
      </div>

      <div className="m-body">
        <div className="m-list">
          <div className="m-section">Pinned</div>
          <ul>{pinned.map(row)}</ul>
          <div className="m-section">Recent</div>
          <ul>{recent.map(row)}</ul>
        </div>

        <div className="m-preview">
          <p className="m-preview-text">{SELECTED_TEXT}</p>
          <div className="m-details">
            <dl>
              <Detail label="Type" value="Text" />
              <Detail label="Characters" value={String(SELECTED_TEXT.length)} />
              <Detail label="Lines" value={String(SELECTED_TEXT.split("\n").length)} />
              <Detail label="Copied" value="2 min ago" />
            </dl>
            <div className="m-actions">
              <span className="m-copy">
                <CopyIcon />
                Copy
              </span>
              <span className="m-spacer" />
              <span className="m-icon-btn">
                <PinIcon />
              </span>
              <span className="m-icon-btn">
                <TrashIcon />
              </span>
            </div>
          </div>
        </div>
      </div>

      <div className="m-footer">
        <Hint k="↑↓" label="Select" />
        <Hint k="↩" label="Copy" />
        <Hint k="⌘1–9" label="Quick copy" wide />
        <Hint k="⌘P" label="Pin" wide />
        <Hint k="⌘⌫" label="Delete" wide />
        <Hint k="esc" label="Close" />
        <span className="m-spacer" />
        <GearIcon />
      </div>
    </div>
  );
}

function Detail({ label, value }: { label: string; value: string }) {
  return (
    <div>
      <dt>{label}</dt>
      <dd>{value}</dd>
    </div>
  );
}

function Hint({ k, label, wide }: { k: string; label: string; wide?: boolean }) {
  return (
    <span className="m-hint" data-wide={wide || undefined}>
      <span className="m-key">{k}</span>
      {label}
    </span>
  );
}

/* Icons drawn after the SF Symbols the app uses. */

function SearchIcon() {
  return (
    <svg className="m-search-icon" viewBox="0 0 16 16" fill="none" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round">
      <circle cx="7" cy="7" r="5" />
      <path d="M10.7 10.7 14 14" />
    </svg>
  );
}

function TextIcon() {
  return (
    <svg viewBox="0 0 12 12" fill="none" stroke="currentColor" strokeWidth="1.2" strokeLinecap="round">
      <path d="M2 3h8M2 6h6M2 9h7" />
    </svg>
  );
}

function Thumbnail() {
  return (
    <svg viewBox="0 0 24 24" preserveAspectRatio="xMidYMid slice">
      <rect width="24" height="24" fill="#9fd3e6" />
      <circle cx="17" cy="7" r="2.6" fill="#fff6d8" />
      <path d="M0 18 7 11l5 5 4-3 8 6v5H0z" fill="#2f8f78" />
      <path d="M0 21 9 15l6 4 9-2v7H0z" fill="#1e6a5c" />
    </svg>
  );
}

function CopyIcon() {
  return (
    <svg viewBox="0 0 16 16" fill="none" stroke="currentColor" strokeWidth="1.4" strokeLinejoin="round">
      <rect x="5" y="5" width="8.5" height="9" rx="1.8" />
      <path d="M3.5 10.5h-.2A1.3 1.3 0 0 1 2 9.2V3.3C2 2.6 2.6 2 3.3 2h5.4c.7 0 1.3.6 1.3 1.3v.2" />
    </svg>
  );
}

function PinIcon() {
  return (
    <svg viewBox="0 0 16 16" fill="none" stroke="currentColor" strokeWidth="1.4" strokeLinejoin="round" strokeLinecap="round">
      <path d="M5.5 2h5l-.7 4.2 2.2 2.3H4l2.2-2.3z" />
      <path d="M8 8.5V14" />
    </svg>
  );
}

function TrashIcon() {
  return (
    <svg viewBox="0 0 16 16" fill="none" stroke="currentColor" strokeWidth="1.4" strokeLinejoin="round" strokeLinecap="round">
      <path d="M2.5 4h11M6 4V2.6c0-.3.3-.6.6-.6h2.8c.3 0 .6.3.6.6V4M4 4l.7 9.2c0 .5.5.8.9.8h4.8c.5 0 .9-.3.9-.8L12 4" />
    </svg>
  );
}

function GearIcon() {
  return (
    <svg className="m-gear" viewBox="0 0 16 16" fill="none" stroke="currentColor" strokeWidth="1.3">
      <circle cx="8" cy="8" r="2.2" />
      <path d="M6.9 1.5h2.2l.4 1.8 1.2.7 1.8-.6 1.1 1.9-1.4 1.3v1.4l1.4 1.3-1.1 1.9-1.8-.6-1.2.7-.4 1.8H6.9l-.4-1.8-1.2-.7-1.8.6-1.1-1.9 1.4-1.3V7.3L2.4 6 3.5 4.1l1.8.6 1.2-.7z" strokeLinejoin="round" />
    </svg>
  );
}
