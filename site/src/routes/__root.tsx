import type { ReactNode } from "react";
import { HeadContent, Outlet, Scripts, createRootRoute } from "@tanstack/react-router";
import appCss from "../styles.css?url";

const SITE = "https://cliptap.app";
const TITLE = "Cliptap: clipboard history for macOS";
const DESCRIPTION =
  "Clipboard history for macOS. Tap ⌘ twice, pick, paste. Free and open source, keyboard first, and everything stays on your Mac.";
const OG_IMAGE = `${SITE}/og.png`;

const jsonLd = {
  "@context": "https://schema.org",
  "@type": "SoftwareApplication",
  name: "Cliptap",
  operatingSystem: "macOS 14 or later",
  applicationCategory: "UtilitiesApplication",
  description: DESCRIPTION,
  url: SITE,
  downloadUrl: "https://github.com/karnstack/cliptap/releases/latest/download/Cliptap.zip",
  license: "https://opensource.org/licenses/MIT",
  offers: { "@type": "Offer", price: "0", priceCurrency: "USD" },
};

export const Route = createRootRoute({
  head: () => ({
    meta: [
      { charSet: "utf-8" },
      { name: "viewport", content: "width=device-width, initial-scale=1, viewport-fit=cover" },
      { title: TITLE },
      { name: "description", content: DESCRIPTION },
      { name: "color-scheme", content: "light dark" },
      { property: "og:type", content: "website" },
      { property: "og:site_name", content: "Cliptap" },
      { property: "og:url", content: SITE },
      { property: "og:title", content: TITLE },
      { property: "og:description", content: DESCRIPTION },
      { property: "og:image", content: OG_IMAGE },
      { property: "og:image:width", content: "1200" },
      { property: "og:image:height", content: "630" },
      { property: "og:image:alt", content: "Cliptap icon with the text: Clipboard history for macOS. Tap ⌘ twice, pick, paste." },
      { name: "twitter:card", content: "summary_large_image" },
      { name: "twitter:title", content: TITLE },
      { name: "twitter:description", content: DESCRIPTION },
      { name: "twitter:image", content: OG_IMAGE },
    ],
    links: [
      { rel: "canonical", href: SITE },
      { rel: "icon", href: "/favicon.ico", sizes: "32x32" },
      { rel: "icon", href: "/icon.svg", type: "image/svg+xml" },
      { rel: "apple-touch-icon", href: "/apple-touch-icon.png" },
      { rel: "stylesheet", href: appCss },
    ],
  }),
  component: RootComponent,
  notFoundComponent: NotFound,
});

function NotFound() {
  return (
    <main className="page intro">
      <h1>Page not found</h1>
      <p className="pitch">
        <a className="quiet-link" href="/">
          Go to the Cliptap home page
        </a>
      </p>
    </main>
  );
}

function RootComponent() {
  return (
    <RootDocument>
      <Outlet />
    </RootDocument>
  );
}

function RootDocument({ children }: Readonly<{ children: ReactNode }>) {
  return (
    <html lang="en">
      <head>
        <HeadContent />
        {/* Written here because HeadContent keeps only one meta per name. */}
        <meta name="theme-color" content="#fbfcfc" media="(prefers-color-scheme: light)" />
        <meta name="theme-color" content="#0c1111" media="(prefers-color-scheme: dark)" />
        <script
          type="application/ld+json"
          // Static object defined above, safe to inline.
          dangerouslySetInnerHTML={{ __html: JSON.stringify(jsonLd) }}
        />
      </head>
      <body>
        {children}
        <Scripts />
      </body>
    </html>
  );
}
