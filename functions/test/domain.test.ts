import test from "node:test";
import assert from "node:assert/strict";
import {BookingError, checkBookable, dateStart, overlaps, parseBooking, startsAt} from "../src/domain";

const valid = {requestId: "test-request-123", roomId: "room-01", date: "2026-09-14",
  startMinute: 490, endMinute: 575, purpose: "  Project meeting  "};

function rejects(change: Record<string, unknown>): void {
  assert.throws(() => parseBooking({...valid, ...change}), BookingError);
}

test("accepts arbitrary whole-minute times and trims purpose", () => {
  assert.deepEqual(parseBooking(valid), {...valid, purpose: "Project meeting"});
});

test("accepts full opening windows and one-minute boundary bookings", () => {
  for (const [startMinute, endMinute] of [[480, 720], [780, 960], [719, 720], [959, 960]]) {
    assert.equal(parseBooking({...valid, startMinute, endMinute}).startMinute, startMinute);
  }
});

test("rejects outside opening hours, lunch, and empty/reversed durations", () => {
  for (const [startMinute, endMinute] of [[479, 500], [960, 961], [720, 780], [719, 781],
    [700, 730], [760, 800], [480, 480], [600, 500]]) rejects({startMinute, endMinute});
});

test("rejects non-minute and malformed numeric input", () => {
  for (const startMinute of [480.5, "480", null, NaN, Infinity]) rejects({startMinute});
});

test("rejects invalid and non-canonical calendar dates", () => {
  for (const date of ["2026-02-29", "2026-13-01", "2026-00-00", "2026-2-02", "2026-04-31", "2026-09-14T00:00:00Z"]) rejects({date});
  assert.equal(dateStart("2028-02-29"), Date.parse("2028-02-29T00:00:00+07:00"));
});

test("Bangkok timestamps remain independent of host time zone", () => {
  assert.equal(startsAt("2026-09-14", 490), Date.parse("2026-09-14T08:10:00+07:00"));
});

test("rejects Saturday and Sunday", () => {
  for (const date of ["2026-09-19", "2026-09-20"]) {
    assert.throws(() => checkBookable({...parseBooking(valid), date}, 0), /Monday–Friday/);
  }
});

test("rejects start at or before authoritative current instant", () => {
  const input = parseBooking(valid);
  const start = startsAt(input.date, input.startMinute);
  checkBookable(input, start - 1);
  assert.throws(() => checkBookable(input, start), /passed/);
  assert.throws(() => checkBookable(input, start + 1), /passed/);
});

test("overlap includes containment and allows adjacent intervals", () => {
  const base = {startMinute: 500, endMinute: 600};
  for (const [startMinute, endMinute] of [[510, 590], [480, 620], [590, 610], [490, 510], [500, 600]]) {
    assert.equal(overlaps(base, {startMinute, endMinute}), true);
  }
  for (const [startMinute, endMinute] of [[480, 500], [600, 720]]) {
    assert.equal(overlaps(base, {startMinute, endMinute}), false);
  }
});

test("validates request IDs, room IDs, purpose length and required object", () => {
  for (const requestId of ["tiny", "x/unsafe-key", "a".repeat(129)]) rejects({requestId});
  for (const roomId of ["room-07", "../rooms", null]) rejects({roomId});
  for (const purpose of ["", "   ", "a".repeat(501), null]) rejects({purpose});
  for (const input of [null, [], "text", undefined]) assert.throws(() => parseBooking(input), BookingError);
});
