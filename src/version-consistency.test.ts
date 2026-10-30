import fs from "node:fs";
import path from "node:path";
import { describe, expect, it } from "vitest";
import { APP_VERSION } from "./types";

const root = process.cwd();

function read(relativePath: string): string {
  return fs.readFileSync(path.join(root, relativePath), "utf8");
}

// The iOS client came back after desktop 2.7.0 had shipped without it, still
// carrying the 2.6.7+187 it was restored with. That is the only accepted
// mismatch: the next release gives mobile/pubspec.yaml and appVersion the
// package.json version and raises the build number, as every release did.
const restoredMobile = { desktop: "2.7.0", version: "2.6.7", build: 187 };

describe("release version consistency", () => {
  it("keeps desktop user-facing versions aligned with package.json", () => {
    const packageVersion = JSON.parse(read("package.json")).version as string;
    const mcpClient = read("electron/ipc/mcp-client.ts");

    expect(APP_VERSION).toBe(packageVersion);
    expect(mcpClient).toContain(`version: "${packageVersion}"`);
  });

  it("keeps the iOS version aligned with package.json from the next release on", () => {
    const packageVersion = JSON.parse(read("package.json")).version as string;
    const pubspec = read("mobile/pubspec.yaml").match(/^version:\s*(\d+\.\d+\.\d+)\+(\d+)\s*$/m);
    const appVersion = read("mobile/lib/models/nai_models.dart")
      .match(/^const appVersion = '([^']+)';\s*$/m)?.[1];
    const infoPlist = read("mobile/ios/Runner/Info.plist");

    expect(pubspec).not.toBeNull();
    const mobile = { version: pubspec![1], build: Number(pubspec![2]) };
    // The app shows appVersion; the IPA takes its version and build number from pubspec.yaml.
    expect(appVersion).toBe(mobile.version);
    expect(infoPlist).toMatch(/<key>CFBundleShortVersionString<\/key>\s*<string>\$\(FLUTTER_BUILD_NAME\)<\/string>/);
    expect(infoPlist).toMatch(/<key>CFBundleVersion<\/key>\s*<string>\$\(FLUTTER_BUILD_NUMBER\)<\/string>/);

    if (packageVersion === restoredMobile.desktop && mobile.version !== packageVersion) {
      expect(mobile).toEqual({ version: restoredMobile.version, build: restoredMobile.build });
    } else {
      expect(mobile.version).toBe(packageVersion);
      expect(mobile.build).toBeGreaterThan(restoredMobile.build);
    }
  });

  it("derives the desktop display version instead of hard-coding it", () => {
    const desktopVersionSource = read("src/types.ts");

    expect(desktopVersionSource).toContain(
      'import { version as packageVersion } from "../package.json";',
    );
    expect(desktopVersionSource).toContain(
      "export const APP_VERSION = packageVersion;",
    );
  });

  it("uses moving Latest and main entries in the README", () => {
    const repo = "https://github.com/OldLi1337/novelai-image-desktop";
    const readme = read("README.md");
    const releaseLinks = readme.match(/https?:\/\/[^\s)\]<>"']+\/releases(?:\/[^\s)\]<>"']*)?/g) ?? [];

    expect(readme).not.toContain("gitee.com");
    expect(readme).toContain(`${repo}/releases/latest`);
    expect(readme).toContain(`${repo}/tree/main`);
    expect(releaseLinks.length).toBeGreaterThan(0);
    for (const link of releaseLinks) {
      expect(link).toBe(`${repo}/releases/latest`);
    }
    // Dated screenshots and historical facts may retain their real versions.
    expect(readme.split(/\r?\n/).slice(0, 12).join("\n"))
      .not.toMatch(/\bv?\d+\.\d+\.\d+\b/i);
    const download = readme.split(/^## /m).find((section) => /^下载与安装\r?\n/.test(section));
    expect(download).toBeDefined();
    expect(download).not.toMatch(/\bv?\d+\.\d+\.\d+\b/i);
  });

  it("uses current-only Latest notes and preserves byte-authentic history separately", () => {
    const repo = "https://github.com/OldLi1337/novelai-image-desktop";
    const releaseNotes = read("docs/RELEASE_NOTES.md");
    const entries = [...releaseNotes.matchAll(/^##\s+.+$/gm)];
    expect(entries.length).toBe(1);
    const first = releaseNotes.slice(entries[0].index);

    expect(entries[0][0]).toMatch(/^## Latest\b/);
    expect(first).toContain(`${repo}/releases/latest`);
    expect(first).toContain(`${repo}/tree/main`);
    expect(first).not.toMatch(/\bv?\d+\.\d+\.\d+\b|\/releases\/(?:tag|download)\/|\/(?:tree|blob|commit)\/[a-f0-9]{7,40}\b/i);
    const history = read("docs/history/RELEASE_NOTES-through-2.5.8.md");
    expect(history).toMatch(/\bv?\d+\.\d+\.\d+\b/);
    expect(history).toContain("2026-10-12");
    expect(releaseNotes).not.toContain("## 2026-10-12");
  });
});
