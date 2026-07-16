# Live Testing Log — 2026-07-16

Short log of the live verification pass against the running app (via
`docker-compose`), run after the initial source-review pass that produced
the test plan and bug tickets. Kept for traceability of how each ticket's
status moved from "source-confirmed" to "live-verified."

## Session summary

1. Ran the automated spec suite (`bundle exec rspec spec/requests`)
   against the freshly deployed container.
2. **BUG-01 (SQLi):** confirmed. Searching `nonexistent-term' OR '1'='1`
   returned every post in the system instead of zero matches.
3. **BUG-02 (XSS) — feed page:** confirmed. A stored `<script>` payload
   came back verbatim in the public home page response.
4. **BUG-02 (XSS) — individual post page:** the equivalent automated
   check initially came back as a false pass. Root cause: `/posts/:id`
   requires authentication (only the feed is public), and the original
   spec wasn't signed in — it just got redirected to the login page and
   never rendered the post at all. Fixed the spec to sign in first, then
   manually confirmed via a signed-in browser session: creating a post
   with body `<script>alert(1)</script>` and opening its permalink page
   rendered the tag live and unescaped in the page source. Ticket and
   test plan updated to reflect that `/posts/:id` requires login (an
   earlier assumption in the test plan had this wrong — corrected).
5. **BUG-03 (broken update):** confirmed. Editing a post's title and
   saving showed a "Post was saved" success message, but reloading the
   post showed the original, unedited title.
6. **BUG-07 (unhandled exception on cross-user edit):** found while
   testing BUG-03. A non-owning user's edit attempt is correctly blocked
   from persisting (authorization holds), but does so via an unrescued
   `ActiveRecord::RecordNotFound` rather than a graceful response.
   Logged as its own ticket since it's a distinct, lower-severity issue
   from BUG-03. Rails' default production config typically auto-rescues
   this into a generic 404 — worth a final manual check
   (`/posts/<id>/edit` as a non-owner) to confirm production behavior
   matches the test-environment result.

## Not yet live-verified

BUG-04 (search wildcard inconsistency), BUG-05 (feed ordering), and
BUG-06 (plans page fragile to external API) remain source-confirmed
only — flagged in `docs/bug-tickets.md` for a follow-up pass.
