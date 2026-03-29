const test = require("node:test");
const assert = require("node:assert/strict");

const {
  getStressLevel,
  getPulseRate,
  getBreathingRate,
  makeFriendshipID,
  toDateStr,
} = require("../lib/utils.js");

test("getStressLevel returns stored stress when present", () => {
  assert.equal(getStressLevel({stressLevel: 73, pulseRate: 90, breathingRate: 20}), 73);
});

test("getStressLevel derives stress from pulse and breathing", () => {
  assert.equal(getStressLevel({pulseRate: 80, breathingRate: 16}), 50);
});

test("getStressLevel clamps derived stress to 100", () => {
  assert.equal(getStressLevel({pulseRate: 220, breathingRate: 40}), 100);
});

test("getPulseRate prefers pulseRate and falls back to heartRate", () => {
  assert.equal(getPulseRate({pulseRate: 71, heartRate: 65}), 71);
  assert.equal(getPulseRate({heartRate: 65}), 65);
  assert.equal(getPulseRate({}), null);
});

test("getBreathingRate prefers breathingRate and falls back to respiratoryRate", () => {
  assert.equal(getBreathingRate({breathingRate: 15, respiratoryRate: 18}), 15);
  assert.equal(getBreathingRate({respiratoryRate: 18}), 18);
  assert.equal(getBreathingRate({}), null);
});

test("makeFriendshipID is order-independent", () => {
  assert.equal(makeFriendshipID("z-user", "a-user"), "a-user_z-user");
  assert.equal(makeFriendshipID("a-user", "z-user"), "a-user_z-user");
});

test("toDateStr uses ISO calendar date", () => {
  assert.equal(toDateStr(new Date("2026-03-28T22:45:00.000Z")), "2026-03-28");
});
