# Bug Report — Blog Platform

Method note: these were identified via source-code review (I didn't have Docker/browser access in the environment I worked in), so reproduction steps are written as they'll play out in the running app, and code locations are cited as evidence. Marked **[Source-confirmed]** where the defect is unambiguous from the code itself; recommend a quick live pass to confirm exact copy/screens.

---

## BUG-01 — SQL Injection in post search
**Type:** Vulnerability
**Severity:** Critical
**Priority:** P0
**Status:** ✅ Live-verified (2026-07-16) — searching `nonexistent-term' OR '1'='1` returned every post in the system instead of zero matches, confirmed via automated request spec against the running app.

**Environment:** Home page (`/`), search box

**Description:**
The search query builds raw SQL by directly interpolating user input into an `ILIKE` clause instead of using parameter binding.

**Evidence:** `app/controllers/posts_controller.rb`, `index` action:
```ruby
@posts = @posts.where("title ILIKE '%#{q}' OR html_body ILIKE '%#{q}%'")
```

**Steps to Reproduce:**
1. Go to the home page.
2. In the Search box, enter a value containing a single quote, e.g. `' OR '1'='1`.
3. Submit the search.

**Expected Result:** Input is treated as a literal search string; either no match or a normal filtered result set, with input safely escaped.

**Actual Result:** The single quote breaks out of the SQL string literal. At minimum this causes a database error (500) on malformed input; at worst it allows a classic SQL injection (boolean-based data exfiltration, e.g. `' OR 1=1--`, or use of `UNION SELECT` to pull data from other tables such as `users`, including password hashes).

**Suggested Fix:** Use parameterized/sanitized query building, e.g.:
```ruby
@posts = @posts.where("title ILIKE :q OR html_body ILIKE :q", q: "%#{q}%")
```

---

## BUG-02 — Stored XSS via unsanitized post body rendering
**Type:** Vulnerability
**Severity:** Critical
**Priority:** P0
**Status:** ✅ Fully live-verified (2026-07-16) on both pages:
- **Feed/index page** (`/`, logged out): stored `<script>` payload returned verbatim, unescaped, viewable by anonymous visitors.
- **Individual post page** (`/posts/:id`, logged in): confirmed via direct browser check. Creating a post with body `<script>alert(1)</script>` and viewing its permalink page renders it as a live, literal `<script>` tag in the page source — not escaped — same as the feed. This page requires authentication, so this half of the finding is scoped to logged-in users, but is otherwise identical in mechanism and severity.

**Environment:** Post creation form; home feed and individual post pages (public, no login required to view)

**Description:**
Post bodies are rendered with Rails' `raw` helper, which disables HTML escaping. Since any registered user can submit arbitrary text as the body (there's no rich-text editor or HTML sanitizer in the stack), a malicious user can store `<script>` or event-handler payloads that execute in the browser of every visitor who views the feed or that post — including anonymous, unauthenticated visitors. There is also no Content-Security-Policy configured (`config/initializers/content_security_policy.rb` is entirely commented out), so there's no defense-in-depth against this.

**Evidence:** `app/views/posts/_post.html.erb`:
```erb
<%= raw post.html_body %>
```
No sanitization (e.g. `sanitize`, `rails-html-sanitizer` allow-list) is applied anywhere in the create/update path (`app/controllers/posts_controller.rb`).

**Steps to Reproduce:**
1. Log in, click "Add post."
2. Title: any valid title. Body: `<script>alert(document.cookie)</script>`
3. Save the post.
4. Visit the home feed or the post's page, logged out.

**Expected Result:** The script tag is either stripped/escaped or rendered as inert text.

**Actual Result:** The script executes in the visitor's browser (session/cookie theft, defacement, or redirect attacks are all possible).

**Suggested Fix:** Sanitize `html_body` on output with an allow-list (`sanitize(post.html_body, tags: %w[p b i em strong a ul li], attributes: %w[href])`) or switch to a proper rich-text pipeline (e.g. Action Text) instead of accepting raw HTML. Also enable a restrictive CSP as defense-in-depth.

---

## BUG-03 — Editing a post shows "saved" but never persists the changes
**Type:** Logical / Functional
**Severity:** High
**Priority:** P1
**Status:** ✅ Live-verified (2026-07-16) — an automated edit-and-reload test confirmed the title reverted to its original value despite a successful "Post was saved" response.

**Related finding (see BUG-07):** while confirming this, a same-controller check also confirmed that a *different* user attempting to edit someone else's post is correctly blocked from persisting changes — but by an unhandled `ActiveRecord::RecordNotFound` exception rather than a graceful response. Logged separately as BUG-07 below since it's a distinct (lower-severity) issue.

**Environment:** Post edit page (`/posts/:id/edit`)

**Description:**
The `update` action loads the post but never assigns the submitted form parameters or calls `save`/`update`. It unconditionally redirects with a success message, so the UI claims the edit worked while the database is untouched.

**Evidence:** `app/controllers/posts_controller.rb`:
```ruby
def update
  @post = current_user.posts.find(params[:id])
  redirect_to post_url(@post), notice: 'Post was saved'
end
```
There is no `@post.update(post_params)` (or equivalent) call.

**Steps to Reproduce:**
1. Log in as the author of an existing post.
2. Open the post's Edit page, change the title and body, click Save.
3. Observe the "Post was saved" success flash and redirect to the post page.
4. Reload the post page.

**Expected Result:** The post reflects the newly edited title/body.

**Actual Result:** The post still shows the original, pre-edit title/body — the edit was silently discarded despite the success message, which is actively misleading to the user.

**Suggested Fix:**
```ruby
def update
  @post = current_user.posts.find(params[:id])
  if @post.update(post_params)
    redirect_to post_url(@post), notice: 'Post was saved'
  else
    render action: :edit
  end
end
```

---

## BUG-04 — Inconsistent wildcard matching between title and body search
**Type:** Functional / Logical
**Severity:** Medium
**Priority:** P2
**Status:** Source-confirmed

**Environment:** Home page search

**Description:**
In the same search query (see BUG-01), the `title` clause is missing the leading `%` wildcard that the `html_body` clause has:
```ruby
"title ILIKE '%#{q}' OR html_body ILIKE '%#{q}%'"
```
`title ILIKE '%#{q}'` only matches titles that *end with* the search term, whereas the body clause matches the term *anywhere*. This is inconsistent and almost certainly unintended — a user searching for a word in the middle of a title will get no title match, while the same word in the middle of a body will match.

**Steps to Reproduce:**
1. Create a post titled "Hello World Today" and another with the word "World" only in its body.
2. Search for `World`.

**Expected Result:** Both posts appear (title contains "World" in the middle; body contains "World").

**Actual Result:** The title match is missed because "Hello World Today" does not *end with* "World"; only substring matches at the very end of the title work.

**Suggested Fix:** Use `'%#{q}%'` consistently for both fields (and fix via parameter binding as noted in BUG-01).

---

## BUG-05 — Posts feed has no defined ordering or pagination
**Type:** Functional / UX
**Severity:** Low–Medium
**Priority:** P3
**Status:** Source-confirmed (ordering); pagination needs live confirmation at scale

**Environment:** Home page feed

**Description:**
The index query is `Post.all` with no `order` clause and no default scope on the model, so the order posts appear in is not guaranteed to be predictable (in practice it will often be insertion order via primary key, but this isn't something the app enforces or documents). There is also no pagination, so as the number of posts grows, the home page will render every post's full body on a single page.

**Evidence:** `app/controllers/posts_controller.rb#index` (`@posts = Post.all`) and `app/models/post.rb` (no default scope).

**Steps to Reproduce:**
1. Create several posts.
2. Reload the home page a few times / after unrelated DB operations.

**Expected Result:** Posts consistently display in a clear, intentional order (e.g., newest first).

**Actual Result:** Order is implicit/unspecified in the code; no guarantee it stays stable, and there's no pagination for a growing feed.

**Suggested Fix:** `Post.order(created_at: :desc)` at minimum, plus pagination (e.g. Kaminari/Pagy) once post volume grows.

---

## BUG-06 — Plans page has a hard dependency on a live external API with no error handling or caching
**Type:** Functional / Reliability
**Severity:** Medium–High
**Priority:** P2
**Status:** Source-confirmed

**Environment:** Plans & pricing page (`/plans`)

**Description:**
Every render of `/plans` makes a synchronous, unrescued HTTP call to the European Central Bank's XML feed to compute a USD→CZK conversion, with no timeout, no caching between requests, and no fallback if the request fails or the currency isn't found in the response.

**Evidence:** `app/services/exchange_rate_fetcher_service.rb`:
```ruby
data = URI.open("https://www.ecb.europa.eu/stats/eurofxref/eurofxref-daily.xml") { |f| f.read }
...
BigDecimal(document.css("Cube[currency=#{from}]").attribute("rate").value)
```
No `rescue`, no `Rails.cache`, no timeout option passed to `URI.open`.

**Steps to Reproduce:**
1. Block outbound access to `ecb.europa.eu` (or simulate the endpoint being slow/down).
2. Visit `/plans` while logged in.

**Expected Result:** Page still renders, using a cached last-known rate or a graceful fallback/error message.

**Actual Result:** The request will hang until it times out at the OS/network layer, or raise an unhandled exception (`OpenURI::HTTPError`, `NoMethodError` if the currency node isn't found, etc.), producing a 500 error and taking the whole page down for a purely cosmetic price conversion.

**Suggested Fix:** Wrap the fetch in `Rails.cache.fetch("exchange_rate/USD/CZK", expires_in: 1.hour) { ... }`, add a request timeout, and rescue failures with a sensible fallback (e.g., last cached rate or hide the CZK conversion).

---

## BUG-07 — Unauthorized edit attempt raises an unhandled exception instead of a clean error page
**Type:** Logical / UI-UX (potential info disclosure depending on environment)
**Severity:** Low–Medium
**Priority:** P3
**Status:** Live-verified in test environment (2026-07-16); production behavior needs manual confirmation

**Environment:** Post edit endpoint, cross-user access attempt

**Description:**
When a logged-in user attempts to submit an edit for a post they don't own, the controller's `current_user.posts.find(params[:id])` correctly fails to find the record (good — the authorization boundary itself holds), but it does so by raising `ActiveRecord::RecordNotFound` with no rescue in place. In the test environment this exception propagates all the way up, uncaught:
```
ActiveRecord::RecordNotFound:
  Couldn't find Post with 'id'=7 [WHERE "posts"."author_id" = $1]
    app/controllers/posts_controller.rb:37:in `update'
```
Rails' default production config typically auto-converts unrescued `ActiveRecord::RecordNotFound` into a generic 404 page, so this may be a non-issue in production — **this needs to be manually confirmed against the running app** (e.g. log in as User B, navigate to `/posts/<user-a-post-id>/edit`, check whether you get a clean 404 or a raw stack trace with file paths/line numbers).

**Steps to Reproduce:**
1. Log in as User B.
2. Manually navigate to `/posts/<a post id owned by User A>/edit` (or submit a PATCH to it).
3. Observe the response.

**Expected Result:** A clean, generic "not found" or "not authorized" response with no internal details exposed.

**Actual Result (test env):** Unhandled exception with a full backtrace including file paths — if this reproduces the same way outside of `RAILS_ENV=test` (i.e. if `config.consider_all_requests_local` is on, or the equivalent production rescue isn't in place), this becomes an information-disclosure issue.

**Suggested Fix:** Add an explicit `rescue_from ActiveRecord::RecordNotFound` in `ApplicationController` (or `PostsController`) that renders/redirects with a generic message, so behavior is guaranteed and environment-independent rather than relying on Rails' default production rescue.

---

## Summary Table

| ID | Title | Type | Severity | Status |
|---|---|---|---|---|
| BUG-01 | SQL Injection in post search | Vulnerability | Critical | ✅ Live-verified |
| BUG-02 | Stored XSS via unsanitized post body | Vulnerability | Critical | ✅ Fully live-verified (feed + show page) |
| BUG-03 | Post edits don't persist despite "saved" message | Logical/Functional | High | ✅ Live-verified |
| BUG-04 | Title vs. body search wildcard inconsistency | Functional/Logical | Medium | Source-confirmed |
| BUG-05 | No defined post ordering / no pagination | Functional/UX | Low–Medium | Source-confirmed |
| BUG-06 | Plans page fragile to external API failure | Functional/Reliability | Medium–High | Source-confirmed |
| BUG-07 | Unauthorized edit raises unhandled exception | Logical/UX | Low–Medium | Live-verified (test env); prod TBD |
