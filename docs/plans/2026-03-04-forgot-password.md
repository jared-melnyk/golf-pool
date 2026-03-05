# Forgot Password (Email Link) Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Let locked-out users reset their password via a "Forgot password?" link on the sign-in page. User enters email, receives an email with a one-time link; clicking the link opens a page to set a new password. Link expires in 1 hour and is single-use.

**Architecture:** Token-on-User: add `password_reset_token_digest` and `password_reset_sent_at` to `users`. Generate a secure token when the user requests a reset, store its digest, send email with raw token in URL. Reset page verifies token (constant-time) and expiry, then allows password update and clears the token.

**Tech Stack:** Ruby on Rails, ActiveRecord, Action Mailer, RSpec.

---

### Task 1: Add migration for password reset fields

**Files:**
- Create: `db/migrate/<timestamp>_add_password_reset_to_users.rb`
- Modify: `db/schema.rb` (via migration)

**Step 1: Create migration**

Run: `bin/rails generate migration AddPasswordResetToUsers password_reset_token_digest:string password_reset_sent_at:datetime`

**Step 2: Add index and null constraint (optional but useful)**

Edit the generated migration to add an index on `password_reset_token_digest` only if you plan to look up by token (we look up by finding user and comparing digest, so no index required). Leave columns nullable.

**Step 3: Run migration**

Run: `bin/rails db:migrate`  
Expected: Migration runs successfully.

**Step 4: Commit**

```bash
git add db/migrate/*_add_password_reset_to_users.rb db/schema.rb
git commit -m "db: add password_reset_token_digest and password_reset_sent_at to users"
```

---

### Task 2: User model — token generation, digest, expiry, clear

**Files:**
- Modify: `app/models/user.rb`

**Step 1: Add token generation and digest storage**

In `User`:
- Add method `generate_password_reset_token` that: sets `self.password_reset_token = SecureRandom.urlsafe_base64(32)`, stores digest in `password_reset_token_digest` (use `BCrypt::Password.create` or `Digest::SHA256.hexdigest`), sets `password_reset_sent_at = Time.current`, returns the raw token so the mailer can use it.
- Use a virtual attribute `password_reset_token` (attr_accessor) only in the method; persist only `password_reset_token_digest` and `password_reset_sent_at`.

**Step 2: Add token verification and expiry**

- Add method `password_reset_token_valid?(raw_token)` that returns false if `password_reset_sent_at.blank?` or older than 1 hour (e.g. `password_reset_sent_at < 1.hour.ago`), otherwise compares `raw_token` to stored digest with `ActiveSupport::SecurityUtils.secure_compare(Digest::SHA256.hexdigest(raw_token), password_reset_token_digest)` (if using SHA256) or equivalent for BCrypt (`BCrypt::Password.new(password_reset_token_digest) == raw_token`). Use one hashing strategy consistently.
- Recommendation: use `Digest::SHA256.hexdigest(raw_token)` for digest and store that; then `secure_compare( digest(raw_token), password_reset_token_digest )` and expiry check.

**Step 3: Add clear method**

- Add method `clear_password_reset!` that sets `password_reset_token_digest = nil`, `password_reset_sent_at = nil`, and `save!` (or update_columns to skip validations).

**Step 4: Commit**

```bash
git add app/models/user.rb
git commit -m "feat: User password reset token generation, verification, and clear"
```

---

### Task 3: Routes for forgot password and password reset

**Files:**
- Modify: `config/routes.rb`

**Step 1: Add routes**

Add:

```ruby
get "forgot_password", to: "password_resets#new", as: :forgot_password
post "forgot_password", to: "password_resets#create"
get "password_reset/:token", to: "password_resets#edit", as: :edit_password_reset
patch "password_reset/:token", to: "password_resets#update", as: :password_reset
```

**Step 2: Commit**

```bash
git add config/routes.rb
git commit -m "routes: add forgot_password and password_reset"
```

---

### Task 4: PasswordResetsController — new and create (forgot form + send email)

**Files:**
- Create: `app/controllers/password_resets_controller.rb`
- Create: `app/views/password_resets/new.html.erb`

**Step 1: Controller with skip require_login**

Create `PasswordResetsController`:
- `skip_before_action :require_login, only: [ :new, :create, :edit, :update ]`
- `def new` — render forgot-password form (no @user needed if form is just email field; or set `@user = User.new` for potential form object).
- `def create` — permit `:email`. Downcase email. Find user by email. If user present: call `user.generate_password_reset_token` (implement in Task 2 to return raw token), then `UserMailer.password_reset(user, raw_token).deliver_later`. Always redirect to login_path with notice: "If an account exists for that email, we've sent a link to reset your password. Check your inbox and spam." (No branching on user presence in the response.)

**Step 2: Forgot password view**

Create `app/views/password_resets/new.html.erb` with same layout/styling as `sessions/new`: title "Forgot password?", form with `url: forgot_password_path`, method post, single email field (required), submit "Send reset link". At bottom: link back to "Sign in" (login_path).

**Step 3: Commit**

```bash
git add app/controllers/password_resets_controller.rb app/views/password_resets/new.html.erb
git commit -m "feat: forgot password form and create action"
```

---

### Task 5: UserMailer and password reset email

**Files:**
- Create: `app/mailers/user_mailer.rb`
- Create: `app/views/user_mailer/password_reset.html.erb`
- Create: `app/views/user_mailer/password_reset.text.erb`

**Step 1: UserMailer#password_reset**

In `UserMailer`, add:
- `def password_reset(user, raw_token)` — set @user = user, @reset_url = edit_password_reset_url(token: raw_token). mail to: user.email, subject: "Reset your password" (or similar).

**Step 2: Email templates**

- HTML: Short message "You requested a password reset. Click the link below to set a new password. This link expires in 1 hour." + link "Reset your password" → @reset_url.
- Text: Same content with plain URL.

**Step 3: Commit**

```bash
git add app/mailers/user_mailer.rb app/views/user_mailer/
git commit -m "feat: UserMailer password reset email"
```

---

### Task 6: PasswordResetsController — edit and update (reset form + set new password)

**Files:**
- Modify: `app/controllers/password_resets_controller.rb`
- Create: `app/views/password_resets/edit.html.erb`

**Step 1: Find user by token for edit/update**

Add private method `set_user_by_token`: set @user by iterating users that have `password_reset_token_digest` present and call `user.password_reset_token_valid?(params[:token])`. If found, set @user; else @user = nil. Use `before_action :set_user_by_token, only: [ :edit, :update ]`. In edit/update, if @user.blank? redirect to login_path with alert "That link is invalid or has expired." and return.

**Step 2: edit and update actions**

- `def edit` — render form with @user (for password and password_confirmation fields; we don't expose token in form, it's in URL).
- `def update` — permit :password, :password_confirmation. If @user.update(permitted params), call @user.clear_password_reset!, redirect to login_path with notice "Password updated. Sign in with your new password." Else render :edit with status :unprocessable_entity.

**Step 3: Reset password view**

Create `app/views/password_resets/edit.html.erb`: title "Set new password", form with `url: password_reset_path(token: params[:token])`, method patch. Fields: password, password_confirmation (same styling as signup form). Submit "Update password". Show @user.errors if any.

**Step 4: Commit**

```bash
git add app/controllers/password_resets_controller.rb app/views/password_resets/edit.html.erb
git commit -m "feat: password reset edit/update and set new password"
```

---

### Task 7: Add "Forgot password?" link to sign-in page

**Files:**
- Modify: `app/views/sessions/new.html.erb`

**Step 1: Add link**

In the paragraph that has "Sign up", add a "Forgot password?" link to forgot_password_path, same style as the Sign up link (e.g. `text-emerald-600 hover:underline`). Example: "Forgot password? | Sign up" or put Forgot password on its own line below the form.

**Step 2: Commit**

```bash
git add app/views/sessions/new.html.erb
git commit -m "ui: add Forgot password link to sign-in page"
```

---

### Task 8: Request specs for forgot password and password reset

**Files:**
- Create: `spec/requests/password_resets_spec.rb`

**Step 1: Write request specs**

- GET /forgot_password: returns 200 and shows "Forgot password" and email field.
- POST /forgot_password with valid email (user exists): sends email (assert ActionMailer::Base.deliveries), redirects to login with success notice.
- POST /forgot_password with unknown email: redirects to login with same success notice (no email sent).
- GET /password_reset/:token with valid token: returns 200 and shows "Set new password" form.
- GET /password_reset/:token with invalid/expired token: redirects to login with "invalid or expired" message.
- PATCH /password_reset/:token with valid token and valid password: updates password, clears token, redirects to login with success; user can then sign in with new password.
- PATCH /password_reset/:token with invalid token: redirects to login with error.
- PATCH /password_reset/:token with valid token but invalid password (e.g. confirmation mismatch): re-renders edit with 422 and errors.

**Step 2: Run specs**

Run: `bin/rspec spec/requests/password_resets_spec.rb`  
Expected: All examples pass.

**Step 3: Commit**

```bash
git add spec/requests/password_resets_spec.rb
git commit -m "test: request specs for forgot password and password reset"
```

---

### Task 9: User model specs for token and expiry

**Files:**
- Modify: `spec/models/user_spec.rb` (create if missing)

**Step 1: Add specs for password reset behavior**

- `generate_password_reset_token` sets `password_reset_token_digest` and `password_reset_sent_at` and returns a raw token string.
- `password_reset_token_valid?(raw_token)` returns true for the token just generated and false for wrong token.
- `password_reset_token_valid?` returns false when token is older than 1 hour (travel time or set `password_reset_sent_at` to 2.hours.ago).
- `clear_password_reset!` nils digest and sent_at.

**Step 2: Run specs**

Run: `bin/rspec spec/models/user_spec.rb`  
Expected: All pass.

**Step 3: Commit**

```bash
git add spec/models/user_spec.rb
git commit -m "test: User password reset token and expiry specs"
```

---

### Task 10: Mailer spec (optional but recommended)

**Files:**
- Create: `spec/mailers/user_mailer_spec.rb`

**Step 1: Mailer spec**

- `password_reset` sends email to user with reset link containing the raw token (e.g. body or URL includes the token).

**Step 2: Run full test suite**

Run: `bin/rspec`  
Expected: All specs pass.

**Step 3: Commit**

```bash
git add spec/mailers/user_mailer_spec.rb
git commit -m "test: UserMailer password_reset spec"
```

---

### Task 11: Manual smoke test and verification

**Steps:**
- Start app (`bin/rails s`). Open sign-in, click "Forgot password?", submit an email that exists; check logs or letter_opener for email and click link; set new password, sign in with new password.
- Submit a non-existent email and confirm same success message and no error.
- Open an expired or invalid reset link and confirm redirect and message.

No code changes; document in PR or handoff that smoke test was done.
