import { createFileRoute } from "@tanstack/react-router";
import { AppMock } from "../components/AppMock";

const DOWNLOAD_URL = "https://github.com/karnstack/cliptap/releases/latest/download/Cliptap.zip";
const GITHUB_URL = "https://github.com/karnstack/cliptap";

export const Route = createFileRoute("/")({
  component: Home,
});

const features = [
  "Keeps the text and images you copy.",
  "Search, pin and delete without leaving the keyboard.",
  "Skips passwords that password managers mark as secret.",
  "Stays on your Mac. No account, no tracking.",
  "Under 1 MB, with near-zero CPU when idle.",
  "Updates install from inside the app.",
];

const shortcuts: { keys: string[][]; action: string }[] = [
  { keys: [["⌘", "⌘"], ["⌃", "⌘", "V"]], action: "Open" },
  { keys: [["↑", "↓"]], action: "Select" },
  { keys: [["↩"]], action: "Copy" },
  { keys: [["⌘", "1–9"]], action: "Copy item 1–9" },
  { keys: [["⌘", "P"]], action: "Pin" },
  { keys: [["⌘", "⌫"]], action: "Delete" },
  { keys: [["esc"]], action: "Close" },
];

function Home() {
  return (
    <>
      <main className="page">
        <header className="intro">
          <img className="intro-icon" src="/icon.svg" width="64" height="64" alt="" />
          <h1>Cliptap</h1>
          <p className="pitch">
            Clipboard history for macOS.
            <br />
            Tap ⌘ twice, pick, paste.
          </p>
          <div className="cta">
            <a className="button" href={DOWNLOAD_URL}>
              Download for Mac
            </a>
            <a className="quiet-link" href={GITHUB_URL}>
              View on GitHub
            </a>
          </div>
          <p className="meta">Free · Open source · macOS 14+</p>
        </header>

        <figure className="stage">
          <div className="stage-inner">
            <AppMock />
          </div>
        </figure>

        <div className="details">
          <section aria-labelledby="what">
            <h2 id="what" className="label">
              What it does
            </h2>
            <ul className="features">
              {features.map((f) => (
                <li key={f}>{f}</li>
              ))}
            </ul>
          </section>

          <section aria-labelledby="keys">
            <h2 id="keys" className="label">
              Shortcuts
            </h2>
            <dl className="shortcuts">
              {shortcuts.map(({ keys, action }) => (
                <div key={action}>
                  <dt>{action}</dt>
                  <dd>
                    {keys.map((combo, i) => (
                      <span key={combo.join("")} className="combo">
                        {i > 0 && <span className="or">or</span>}
                        {combo.map((k) => (
                          <kbd key={k}>{k}</kbd>
                        ))}
                      </span>
                    ))}
                  </dd>
                </div>
              ))}
            </dl>
            <p className="note">
              The double ⌘ shortcut needs Accessibility access. Cliptap asks for it on first launch.
            </p>
          </section>
        </div>
      </main>

      <footer className="footer">
        <div className="footer-inner">
          <a href={`${GITHUB_URL}/blob/main/LICENSE`}>MIT License</a>
          <a href={GITHUB_URL}>GitHub</a>
          <span>
            Made by <a href="https://github.com/karnstack">Karn</a>
          </span>
        </div>
      </footer>
    </>
  );
}
