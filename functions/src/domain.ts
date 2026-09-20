export type ErrorCode = "invalid-argument" | "unauthenticated" | "permission-denied" |
  "not-found" | "failed-precondition" | "already-exists";

export class BookingError extends Error {
  constructor(readonly code: ErrorCode, message: string) {
    super(message);
    this.name = "BookingError";
  }
}

export interface BookingInput {
  requestId: string;
  roomId: string;
  date: string;
  startMinute: number;
  endMinute: number;
  purpose: string;
}

export interface Reservation extends Omit<BookingInput, "requestId"> {
  id: string;
  userId: string;
  status: "confirmed" | "cancelled";
  createdAt: number;
}

export interface Interval {
  reservationId: string;
  startMinute: number;
  endMinute: number;
}

export interface AuthIdentity { uid: string; emailVerified: boolean }

const invalid = (message: string): never => {
  throw new BookingError("invalid-argument", message);
};

export function requireIdentity(auth: AuthIdentity | undefined): AuthIdentity {
  if (!auth?.uid) throw new BookingError("unauthenticated", "Sign in to manage reservations.");
  return auth;
}

export function objectInput(value: unknown): Record<string, unknown> {
  if (value === null || typeof value !== "object" || Array.isArray(value)) {
    return invalid("Reservation details must be an object.");
  }
  return value as Record<string, unknown>;
}

export function parseBooking(value: unknown): BookingInput {
  const data = objectInput(value);
  if (typeof data.requestId !== "string" || !/^[a-zA-Z0-9_-]{8,128}$/.test(data.requestId)) {
    invalid("A valid request ID is required. Please retry the reservation.");
  }
  if (typeof data.roomId !== "string" ||
      !/^(?:room-0[1-6]|(?:3A(?:02|03|13)|4A(?:02|03|04|05|06|07)|5A(?:09|10)|7A(?:02|07)))$/.test(data.roomId)) {
    invalid("Choose a reservable ITD room.");
  }
  if (typeof data.date !== "string") invalid("Choose a valid date.");
  dateStart(data.date as string);
  if (!Number.isInteger(data.startMinute) || !Number.isInteger(data.endMinute)) {
    invalid("Choose start and end times with whole-minute precision.");
  }
  const startMinute = data.startMinute as number;
  const endMinute = data.endMinute as number;
  if (!(startMinute < endMinute && ((startMinute >= 480 && endMinute <= 720) ||
      (startMinute >= 780 && endMinute <= 960)))) {
    invalid("Choose a time within 8:00am–12:00pm or 1:00pm–4:00pm.");
  }
  if (typeof data.purpose !== "string" || !data.purpose.trim() || data.purpose.trim().length > 500) {
    invalid("Enter a booking purpose of 1–500 characters.");
  }
  return {
    requestId: data.requestId as string,
    roomId: data.roomId as string,
    date: data.date as string,
    startMinute,
    endMinute,
    purpose: (data.purpose as string).trim(),
  };
}

/** Bangkok is UTC+07:00 year-round. These values never depend on server locale. */
export function dateStart(date: string): number {
  if (!/^\d{4}-\d{2}-\d{2}$/.test(date)) return invalid("Choose a valid date (YYYY-MM-DD).");
  const [year, month, day] = date.split("-").map(Number);
  const utc = new Date(Date.UTC(year, month - 1, day));
  if (utc.getUTCFullYear() !== year || utc.getUTCMonth() !== month - 1 || utc.getUTCDate() !== day) {
    return invalid("Choose a valid calendar date.");
  }
  return utc.getTime() - 7 * 60 * 60 * 1000;
}

export function startsAt(date: string, minute: number): number {
  return dateStart(date) + minute * 60_000;
}

export function checkBookable(input: BookingInput, now: number): void {
  const weekday = new Date(dateStart(input.date) + 7 * 60 * 60 * 1000).getUTCDay();
  if (weekday === 0 || weekday === 6) {
    throw new BookingError("failed-precondition", "Rooms are available Monday–Friday.");
  }
  if (startsAt(input.date, input.startMinute) <= now) {
    throw new BookingError("failed-precondition", "The start time has passed. Choose a future time.");
  }
}

export function overlaps(a: Pick<Interval, "startMinute" | "endMinute">,
  b: Pick<Interval, "startMinute" | "endMinute">): boolean {
  return a.startMinute < b.endMinute && b.startMinute < a.endMinute;
}

export function sameBooking(a: BookingInput, b: Reservation, userId: string): boolean {
  return b.userId === userId && a.roomId === b.roomId && a.date === b.date &&
    a.startMinute === b.startMinute && a.endMinute === b.endMinute && a.purpose === b.purpose;
}
