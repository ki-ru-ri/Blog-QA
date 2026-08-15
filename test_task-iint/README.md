# Blog Platform — QA Test

## What This Project Is

The application under test was a blog platform — a website where users can sign up, log in, and write and read blog posts — built using a popular web development framework called Ruby on Rails, and packaged with Docker so it could be set up and run consistently on any computer.

This repo contains the original provided application plus the QA work done against it: a feature/test plan, a set of bug tickets, and automated regression specs for the most significant defects found.

## Installation & running the app

(Original setup instructions, unchanged)

1. Install Docker. For MacOS or Windows (WSL 2) install Docker Desktop.
2. Run `docker-compose up -d` in the terminal in this project's folder. Wait several minutes for all greens.
3. Several more minutes are required to create the database and fetch NPM packages. In case you see webpacker or database errors, wait a while longer.
4. Go to http://localhost:3000 for the main app.

## QA deliverables

- [`docs/feature-overview-and-test-plan.md`](docs/feature-overview-and-test-plan.md) —
  what the app does, and the full test plan used to probe it (auth, post
  CRUD, search, access control, the plans page, UI/UX, and basic security
  checks).
- [`docs/bug-tickets.md`](docs/bug-tickets.md) — 7 tickets in standard
  format (logical, functional, UI/UX, and security defects), each with
  severity, reproduction steps, code-level evidence, and a suggested fix.

### Summary of findings

| ID | Title | Severity | Status |
|---|---|---|---|
| BUG-01 | SQL injection in post search | Critical | Live-verified |
| BUG-02 | Stored XSS via unsanitized post body | Critical | Live-verified (feed + show page) |
| BUG-03 | Post edits don't persist despite "saved" message | High | Live-verified |
| BUG-04 | Title vs. body search wildcard inconsistency | Medium | Source-confirmed |
| BUG-05 | No defined post ordering / no pagination | Low–Medium | Source-confirmed |
| BUG-06 | Plans page fragile to external API failure | Medium–High | Source-confirmed |
| BUG-07 | Unauthorized edit raises unhandled exception | Low–Medium | Live-verified (test env) |

## Automated regression tests

Three of the defects above (BUG-01, BUG-02, BUG-03) plus the related
BUG-07 finding are covered by RSpec request specs in `spec/requests/`:

- `search_sql_injection_spec.rb`
- `post_body_xss_spec.rb`
- `post_update_spec.rb`

### Running the tests

```bash
docker-compose exec web bundle install
docker-compose exec web sh -c "RAILS_ENV=test bin/rails db:create db:schema:load"
docker-compose exec web bundle exec rspec
```

All specs are written to **fail against the current, unpatched app** —
they exist to prove the defects are real and to catch regressions once
fixes land. Applying the suggested fixes in `docs/bug-tickets.md` should
turn every one of them green, with one exception noted inline in
`post_update_spec.rb` for BUG-07, which currently asserts on the raised
exception rather than a graceful response — that assertion should be
swapped out once a `rescue_from` is added to handle it cleanly.

## Methodology note

The initial pass over this app was done via full source review (routes,
controllers, models, views, services) rather than live black-box
clicking, then every significant finding was subsequently reproduced
against the actual running app via `docker-compose` — both through the
automated specs and manual browser/curl checks — before being marked
live-verified above.
