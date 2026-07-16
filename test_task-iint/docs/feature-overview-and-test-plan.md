# Blog Platform — Feature Overview & Test Plan

**App under test:** "The blog platform" (Rails 6 app, Docker Compose: `web`, `webpacker`, `db`)
**URL:** http://localhost:3000
**Method note:** Explored via full source review (routes, controllers, models, views, services) — Docker/browser access wasn't available in the environment I did this analysis in. Feature descriptions below reflect what's reachable through the app's navigation; a live click-through is recommended to sanity-check exact copy/wording, which I could not screenshot myself.

---

## 1. Core Features

1. **User registration (Sign up)** — Email + password account creation (Devise `registerable`). No email confirmation step is enforced before login.
2. **Login / Logout** — Standard email + password session login, with "remember me" and a visible logout link in the header when authenticated.
3. **Password recovery** — "Forgot your password?" sends a reset email with a tokenized link (Devise `recoverable`).
4. **Profile management** — Logged-in users can change their email/password (requires current password) or delete their account, via the "Profile" link.
5. **Posts feed (Home)** — Public page (no login required) listing every post in the system, each rendered with title, creation date, and full body.
6. **Post search** — A search box on the home page filters posts by a keyword matched against title and body (case-insensitive substring match), with a "Reset" link to clear it.
7. **Create post** — Logged-in users can author a post with a title and an HTML body field (plain textarea — there's no rich-text editor, the user types raw markup).
8. **View single post** — Each post has its own permalink page; **requires being logged in** (only the home feed is public — visiting a post directly while logged out redirects to the login page).
9. **Edit own post** — Post authors see an "Edit" button on their own posts and can open an edit form.
10. **Delete own post** — Post authors see a "Delete" button (with a JS confirm dialog) on their own posts.
11. **Plans & pricing page** — A login-gated static page showing Monthly/Yearly pricing, with the USD price additionally converted to CZK using a live daily rate fetched from the European Central Bank on every page load.

---

## 2. Test Plan

### 2.1 Scope
Functional, logical, UI/UX, and basic security testing of authentication, post CRUD, search, and the plans page. Cross-browser/mobile responsiveness is out of scope unless noted.

### 2.2 Test Environment
- App deployed locally via `docker-compose up -d`, accessed at `http://localhost:3000`.
- At least two distinct user accounts (User A, User B) to test ownership/authorization boundaries.
- Browser dev tools available for inspecting network requests/responses and manually crafting URLs.

### 2.3 Test Cases

#### A. Authentication & Account Management
| # | Case | Steps | Expected |
|---|---|---|---|
| A1 | Sign up — happy path | Fill valid email + matching passwords ≥6 chars, submit | Account created, auto-logged-in (or redirected to login), header shows logged-in state |
| A2 | Sign up — duplicate email | Register with an email already in use | Form re-renders with "already taken" style error, no duplicate user created |
| A3 | Sign up — password mismatch | Enter different values in password/confirmation | Validation error shown, no account created |
| A4 | Sign up — password too short | Enter a password under Devise's minimum | Validation error, no account created |
| A5 | Login — happy path | Valid credentials | Redirected to home, "Logged in as {email}" shown |
| A6 | Login — wrong password | Valid email, wrong password | Generic invalid-credentials error, no account/user info leaked |
| A7 | Logout | Click "Log out" while logged in | Session ends, header reverts to logged-out links |
| A8 | Forgot password flow | Request reset for a known email, follow emailed link, set new password | Old password stops working, new one logs in |
| A9 | Edit profile — change password | Update password with correct current password | Change succeeds, re-login required with new password |
| A10 | Edit profile — wrong current password | Attempt password change with incorrect current password | Update rejected with validation error |
| A11 | Delete account | Use "Cancel my account" | Account removed, user logged out, cannot log in again with same credentials |

#### B. Posts — Access Control
| # | Case | Steps | Expected |
|---|---|---|---|
| B1 | Anonymous can view feed | Visit `/` while logged out | Post list renders, no auth prompt |
| B2 | Anonymous is redirected from single post page | Visit a post's `/posts/:id` while logged out | Redirected to login (post content requires authentication — only the feed is public) |
| B3 | Anonymous blocked from creating | Visit `/posts/new` while logged out | Redirected to login |
| B4 | Anonymous blocked from Plans page | Visit `/plans` while logged out | Redirected to login |
| B5 | Edit/Delete buttons hidden for non-owned posts | View a post authored by another user while logged in as User B | No Edit/Delete buttons shown |
| B6 | Direct URL access to another user's edit page | While logged in as User B, manually navigate to `/posts/:id/edit` for a post owned by User A | Should be blocked with a clear error/redirect (not a raw stack trace) |
| B7 | Direct URL access to another user's delete | Send a delete request for User A's post while authenticated as User B (e.g., via browser dev tools replaying the form) | Should be blocked; User A's post must remain intact |

#### C. Posts — CRUD & Validation
| # | Case | Steps | Expected |
|---|---|---|---|
| C1 | Create post — happy path | Logged in, fill title + body, submit | Redirect to post page, "Post was created" notice, post visible on feed |
| C2 | Create — missing title | Submit with empty title | Validation error, form re-rendered, nothing saved |
| C3 | Create — title too short | Title under 5 characters | Validation error (per model: min length 5) |
| C4 | Create — title too long | Title over 100 characters | Validation error (per model: max length 100) |
| C5 | Create — missing body | Submit with empty body | Validation error, nothing saved |
| C6 | Edit post — change title/body and save | As the author, edit an existing post's title and body, submit | Post detail page should reflect the *new* title/body |
| C7 | Delete post — confirm | Click Delete, accept confirm dialog | Post removed from feed and no longer reachable by URL |
| C8 | Delete post — cancel | Click Delete, dismiss confirm dialog | Post remains untouched |
| C9 | Feed ordering | Create several posts in sequence | Feed should present them in a predictable, documented order (e.g., newest first) |
| C10 | Large body content | Submit an unusually large HTML body (e.g., 500KB+) | Define/observe expected behavior — accepted, size-limited, or rejected |

#### D. Search
| # | Case | Steps | Expected |
|---|---|---|---|
| D1 | Search — match in title | Enter a keyword known to be in a post's title | Only matching posts shown |
| D2 | Search — match in body | Enter a keyword only present in a post's body | Matching post(s) shown |
| D3 | Search — case insensitivity | Search using different letter casing than stored text | Match still found |
| D4 | Search — no results | Search for a string that matches nothing | Empty state shown, no error |
| D5 | Search — empty query submitted | Submit search with blank field | Behaves same as unfiltered feed |
| D6 | Search — reset | Use the "Reset" link after searching | Full unfiltered feed restored |
| D7 | Search — special characters | Search using `%`, `_`, `'`, `"`, `--`, `;` and SQL-style payloads (e.g., `' OR '1'='1`) | App should not error out or return unintended results; input should be safely handled |
| D8 | Search — script/HTML payload | Search using `<script>alert(1)</script>` | Should render as inert text, not execute, and not appear reflected unescaped in the page |

#### E. Plans & Pricing Page
| # | Case | Steps | Expected |
|---|---|---|---|
| E1 | Page loads with pricing | Visit `/plans` while logged in | Monthly/Yearly cards render with USD and converted CZK values |
| E2 | Yearly discount math | Compare yearly USD price to 12x monthly | Discount percentage/label matches actual math |
| E3 | External rate source unavailable/slow | Simulate the ECB feed being unreachable or slow (e.g., block the domain, throttle network) | Page should degrade gracefully (fallback/cached value or friendly error) rather than hang or 500 |
| E4 | Repeated visits | Reload `/plans` multiple times quickly | Should not noticeably slow down or hit rate limits due to repeated external calls |

#### F. UI/UX & General
| # | Case | Steps | Expected |
|---|---|---|---|
| F1 | Navigation links | Click every header link (Home, Sign in/up or Profile/Log out, Plans) in both auth states | All links route correctly, no dead links |
| F2 | Flash messages | Trigger success/error actions | Correct alert style (info vs. danger) and dismiss button work |
| F3 | Empty feed state | With zero posts in the system | Feed page shows something reasonable rather than a blank area |
| F4 | Responsive layout | Resize browser to mobile width | Layout, buttons, and form remain usable |
| F5 | 404 handling | Visit a non-existent post ID | Friendly not-found handling, not a raw exception/trace |

#### G. Basic Security Checks
| # | Case | Steps | Expected |
|---|---|---|---|
| G1 | Stored content rendering | Create a post with embedded `<script>` / `<img onerror=...>` in the body | Content should not execute as active script in other users' browsers |
| G2 | SQL-injection probes in search | See D7 | No SQL errors surfaced, no unintended data exposure |
| G3 | CSRF token presence | Inspect forms for `authenticity_token` | Present on all state-changing forms |
| G4 | Session persistence after password change | Change password, check if old sessions elsewhere are invalidated | Note actual behavior (Devise default may not invalidate other sessions) |
