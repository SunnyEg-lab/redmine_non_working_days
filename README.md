# redmine_non_working_days

A Redmine plugin that manages non-working days — public holidays, custom fixed dates, and recurring rules — and reflects them in Gantt charts and an external REST API.

## Features

- **Public holiday import** — fetch public holidays per country/year via the [Nager.Date](https://date.nager.at/) API and register them with one click
- **Custom fixed dates** — register one-off non-working days (e.g. summer/winter company holidays)
- **Recurring rules** — define repeating non-working days using one of four patterns, each with an optional valid date range:
  - Specific day(s) of the month (e.g. the 15th and the last day)
  - Last day of the month
  - Nth weekday of the month (e.g. 2nd Friday)
  - Biweekly on a given weekday
- **Gantt chart integration** — non-working days registered here are excluded from Gantt schedule calculations alongside Redmine's standard day-off settings
- **Calendar view** — yearly and monthly calendar views color-coded by kind (public holiday / fixed date / recurring rule / Redmine standard day off), with a "+N" popup for days with many entries
- **Bulk operations** — select-all checkboxes and bulk delete for each list, plus a one-click "delete all non-working day settings" option (with confirmation) that leaves Redmine's native day-off settings untouched
- **REST API** — `GET /non_working_days/api/days.json` lets external systems query non-working days by year or date range, authenticated with Redmine's standard API key
- **i18n** — English and Japanese included

## Tested Environment

| | Version |
|---|---|
| Redmine | 6.0.4.stable |
| Ruby | 3.3.8-p144 |
| Rails | 7.2.2.1 |
| Database | PostgreSQL |

> Other versions may work but have not been verified. Reports via Issues are welcome.

## Requirements

- Redmine 4.0 or higher (based on API compatibility; tested on 6.0.4)

## Installation

1. Clone this repository into your Redmine `plugins` directory:

   ```bash
   git clone https://github.com/SunnyEg-lab/redmine_non_working_days.git /path/to/redmine/plugins/redmine_non_working_days
   ```

2. Run database migrations:

   ```bash
   bundle exec rake redmine:plugins:migrate RAILS_ENV=production
   ```

3. Restart Redmine.

## Permissions

This plugin adds an entry under the **Administration** menu. Viewing and editing non-working days is available to administrators only; no per-project permissions are added.

## Settings

Go to **Administration → Plugins → Redmine Non Working Days** to configure:

- **Nager.Date API Base URL** — the base URL used to fetch public holiday data (defaults to `https://date.nager.at`)
- **Delete All Non-Working Day Settings** — a one-click option (with confirmation) to remove all holidays, fixed dates, and recurring rules registered by this plugin; Redmine's native day-off settings (Administration → Settings → Issue tracking) are not affected

## REST API

```
GET /non_working_days/api/days.json
```

| Parameter | Required | Description | Example |
|---|---|---|---|
| `year` | optional | Target year (defaults to current year) | `2026` |
| `from` / `to` | optional | Date range (`YYYY-MM-DD`); takes precedence over `year` | `2026-04-16` / `2027-04-15` |
| `kind` | optional | Filter by kind, comma-separated | `holiday,custom_fixed` |

Authenticate with Redmine's standard REST API key, either via the `X-Redmine-API-Key` header or a `key` query parameter. The REST API must be enabled in **Administration → Settings → API**.

## License

This plugin is released under the same license as Redmine itself (GNU General Public License v2 or later).
