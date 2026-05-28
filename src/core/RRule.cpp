#include "RRule.h"

#include <QStringList>

namespace dias {

namespace {

constexpr int kSafetyCap = 366;  // never expand more than this many instances

int dayCodeToQt(const QString& code) {
    if (code == "MO") return 1;
    if (code == "TU") return 2;
    if (code == "WE") return 3;
    if (code == "TH") return 4;
    if (code == "FR") return 5;
    if (code == "SA") return 6;
    if (code == "SU") return 7;
    return 0;
}

QDateTime parseIcsTimestamp(const QString& s) {
    // YYYYMMDDTHHMMSS[Z]
    if (s.length() < 8) return {};
    QString clean = s;
    if (clean.endsWith('Z')) clean.chop(1);

    QDateTime out;
    if (clean.length() == 8) {
        out = QDateTime::fromString(clean, "yyyyMMdd");
    } else if (clean.length() == 15 && clean[8] == 'T') {
        out = QDateTime::fromString(clean, "yyyyMMddTHHmmss");
    }
    return out;
}

} // namespace

RRule RRule::parse(const QString& src) {
    RRule r;
    if (src.isEmpty()) return r;

    QString s = src.trimmed();
    if (s.startsWith("RRULE:", Qt::CaseInsensitive)) s = s.mid(6);

    for (const QString& part : s.split(';', Qt::SkipEmptyParts)) {
        const int eq = part.indexOf('=');
        if (eq <= 0) continue;
        const QString key = part.left(eq).trimmed().toUpper();
        const QString val = part.mid(eq + 1).trimmed();

        if (key == "FREQ") {
            const QString u = val.toUpper();
            if      (u == "DAILY")   r.freq = Freq::Daily;
            else if (u == "WEEKLY")  r.freq = Freq::Weekly;
            else if (u == "MONTHLY") r.freq = Freq::Monthly;
            else if (u == "YEARLY")  r.freq = Freq::Yearly;
        } else if (key == "INTERVAL") {
            const int n = val.toInt();
            if (n > 0) r.interval = n;
        } else if (key == "COUNT") {
            const int n = val.toInt();
            if (n > 0) r.count = n;
        } else if (key == "UNTIL") {
            r.until = parseIcsTimestamp(val);
        } else if (key == "BYDAY") {
            for (const QString& code : val.split(',', Qt::SkipEmptyParts)) {
                // Strip any leading offset like "+2MO" — display-only, we ignore it.
                QString c = code.trimmed().right(2).toUpper();
                const int q = dayCodeToQt(c);
                if (q > 0) r.byday.append(q);
            }
        }
    }
    return r;
}

QVector<QDateTime> RRule::expand(const QDateTime& dtStart,
                                 const QDateTime& windowStart,
                                 const QDateTime& windowEnd) const {
    QVector<QDateTime> out;
    if (!isValid() || !dtStart.isValid()) return out;
    if (!windowStart.isValid() || !windowEnd.isValid()) return out;
    if (windowEnd <= windowStart) return out;

    auto withinCaps = [&](const QDateTime& instance, int produced) {
        if (count > 0 && produced >= count) return false;
        if (until.isValid() && instance > until) return false;
        return true;
    };

    auto pushIfInWindow = [&](const QDateTime& instance) {
        if (instance < windowStart) return;
        if (instance >= windowEnd) return;
        out.append(instance);
    };

    int produced = 0;

    switch (freq) {
        case Freq::Daily: {
            QDateTime cur = dtStart;
            while (cur < windowEnd && out.size() < kSafetyCap) {
                if (!withinCaps(cur, produced)) break;
                pushIfInWindow(cur);
                ++produced;
                cur = cur.addDays(interval);
            }
            break;
        }
        case Freq::Weekly: {
            // If BYDAY is set, emit on each matching weekday within each "week of interval".
            // Otherwise emit weekly on the same weekday as dtStart.
            if (byday.isEmpty()) {
                QDateTime cur = dtStart;
                while (cur < windowEnd && out.size() < kSafetyCap) {
                    if (!withinCaps(cur, produced)) break;
                    pushIfInWindow(cur);
                    ++produced;
                    cur = cur.addDays(7 * interval);
                }
            } else {
                // Walk week-by-week (interval-spaced), emitting BYDAY instances inside that week
                // that are >= dtStart.
                QDate weekStart = dtStart.date().addDays(- ((dtStart.date().dayOfWeek() + 6) % 7));
                const QTime time = dtStart.time();
                while (out.size() < kSafetyCap) {
                    bool anyInWindow = false;
                    for (int dow = 1; dow <= 7; ++dow) {
                        if (!byday.contains(dow)) continue;
                        const QDate d = weekStart.addDays(dow - 1);
                        const QDateTime cand(d, time);
                        if (cand < dtStart) continue;
                        if (!withinCaps(cand, produced)) {
                            return out;
                        }
                        if (cand >= windowStart && cand < windowEnd) {
                            out.append(cand);
                            anyInWindow = true;
                        }
                        ++produced;
                    }
                    weekStart = weekStart.addDays(7 * interval);
                    if (QDateTime(weekStart, time) >= windowEnd && !anyInWindow) break;
                    if (count > 0 && produced >= count) break;
                }
            }
            break;
        }
        case Freq::Monthly: {
            QDateTime cur = dtStart;
            while (cur < windowEnd && out.size() < kSafetyCap) {
                if (!withinCaps(cur, produced)) break;
                pushIfInWindow(cur);
                ++produced;
                cur = cur.addMonths(interval);
            }
            break;
        }
        case Freq::Yearly: {
            QDateTime cur = dtStart;
            while (cur < windowEnd && out.size() < kSafetyCap) {
                if (!withinCaps(cur, produced)) break;
                pushIfInWindow(cur);
                ++produced;
                cur = cur.addYears(interval);
            }
            break;
        }
        case Freq::None: break;
    }

    return out;
}

} // namespace dias
