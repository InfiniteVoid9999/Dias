#pragma once

#include <QDateTime>
#include <QString>
#include <QVector>

namespace dias {

// Minimal RRULE (RFC 5545) parser + expander for *display only*.
// MVP scope per PRD §4.3: parse incoming GCal/Obsidian RRULEs, expand
// instances inside a visible window. Authoring/exceptions are out of scope.
//
// Supported tokens:
//   FREQ=DAILY|WEEKLY|MONTHLY|YEARLY  (required)
//   INTERVAL=<int>                    (default 1)
//   COUNT=<int>                       (optional cap)
//   UNTIL=YYYYMMDDTHHMMSSZ            (optional cap)
//   BYDAY=MO,TU,WE,...                (WEEKLY only; comma-separated)
//
// Anything unrecognized is silently ignored so we never crash on a wild
// RRULE from an external feed — we just emit what we can compute.
struct RRule {
    enum class Freq { None, Daily, Weekly, Monthly, Yearly };

    Freq freq = Freq::None;
    int interval = 1;
    int count = 0;                  // 0 = unbounded
    QDateTime until;                // invalid = unbounded
    QVector<int> byday;             // Qt::Monday=1 .. Qt::Sunday=7

    static RRule parse(const QString& s);

    // Expand starting from dtStart, returning instance starts that fall
    // within [windowStart, windowEnd). dtStart counts as the first instance
    // if it lies in the window. Safety cap: never returns more than 366
    // instances regardless of inputs.
    QVector<QDateTime> expand(const QDateTime& dtStart,
                              const QDateTime& windowStart,
                              const QDateTime& windowEnd) const;

    bool isValid() const { return freq != Freq::None; }
};

} // namespace dias
