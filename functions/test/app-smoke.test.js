const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");

const repoRoot = path.resolve(__dirname, "..", "..");

function readRepoFile(relativePath) {
  return fs.readFileSync(path.join(repoRoot, relativePath), "utf8");
}

test("Swift app exposes the four expected tabs", () => {
  const contentView = readRepoFile("CortisolTracker/ContentView.swift");
  for (const label of ["Dashboard", "Calendar", "Friends", "Tips"]) {
    assert.match(contentView, new RegExp(`Text\\("${label}"\\)`));
  }
});

test("app bootstraps Firebase and gates on authentication", () => {
  const appFile = readRepoFile("CortisolTracker/CortisolTrackerApp.swift");
  assert.match(appFile, /FirebaseApp\.configure\(\)/);
  assert.match(appFile, /if authViewModel\.isAuthenticated/);
  assert.match(appFile, /LoginView/);
  assert.match(appFile, /ContentView/);
});

test("scan flow exposes the current result actions", () => {
  const scanView = readRepoFile("CortisolTracker/Views/Dashboard/ScanView.swift");
  for (const action of ["Save Reading", "Scan Again", "Discard"]) {
    assert.match(scanView, new RegExp(action));
  }
});

test("tips screen uses category-based cards", () => {
  const tipsView = readRepoFile("CortisolTracker/Views/Tips/TipsView.swift");
  assert.match(tipsView, /tip\.category\.icon/);
  assert.match(tipsView, /tip\.category\.rawValue/);
});

test("web mockup exposes the main application screens", () => {
  const mockup = readRepoFile("web-mockup/index.html");
  for (const screenID of [
    "screen-dashboard",
    "screen-calendar",
    "screen-friends",
    "screen-tips",
    "screen-scan",
  ]) {
    assert.match(mockup, new RegExp(`id="${screenID}"`));
  }
});

test("mockup matches the current dashboard and scan vocabulary", () => {
  const mockup = readRepoFile("web-mockup/index.html");
  for (const label of [
    "Today's Readings",
    "Latest Spike",
    "Log Activity",
    "Add Friend",
    "Save Reading",
    "Scan Again",
    "Discard",
  ]) {
    assert.match(mockup, new RegExp(label.replace(/[.*+?^${}()|[\]\\]/g, "\\$&")));
  }
});
