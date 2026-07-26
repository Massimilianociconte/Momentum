import { assertEquals } from "jsr:@std/assert@1";
import { dailyRange, parseDate } from "./google_health.ts";

Deno.test("Google Health rollup uses one civil day, not the previous 24 hours", () => {
  const date = parseDate("2026-07-12");
  assertEquals(date, { year: 2026, month: 7, day: 12 });
  assertEquals(dailyRange(date!), {
    start: {
      date: { year: 2026, month: 7, day: 12 },
      time: { hours: 0, minutes: 0, seconds: 0, nanos: 0 },
    },
    end: {
      date: { year: 2026, month: 7, day: 13 },
      time: { hours: 0, minutes: 0, seconds: 0, nanos: 0 },
    },
  });
});

Deno.test("civil-day range crosses month, year and leap-day boundaries", () => {
  assertEquals(dailyRange(parseDate("2026-12-31")!).end.date, {
    year: 2027,
    month: 1,
    day: 1,
  });
  assertEquals(dailyRange(parseDate("2028-02-29")!).end.date, {
    year: 2028,
    month: 3,
    day: 1,
  });
});

Deno.test("invalid calendar dates are rejected before calling Google", () => {
  assertEquals(parseDate("2026-02-29"), null);
  assertEquals(parseDate("2026-13-01"), null);
  assertEquals(parseDate("2026-07-12T00:00:00Z"), null);
});
