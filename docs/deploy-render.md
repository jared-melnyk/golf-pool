# Deploying long_shot to Render and Connecting a Green Geeks Domain

This guide walks through deploying the app to [Render](https://render.com) and pointing a domain hosted at [Green Geeks](https://www.greengeeks.com/) to it.

## Prerequisites

- GitHub repo with the long_shot app
- A Render account ([sign up](https://dashboard.render.com/register))
- A domain managed in Green Geeks (e.g. `yourdomain.com`)

---

## 1. Deploy to Render from GitHub

### Option A: Blueprint (recommended)

1. Go to [Render Dashboard](https://dashboard.render.com/) → **New** → **Blueprint**.
2. Connect your GitHub account if needed, then select the **long_shot** repository.
3. Render will detect `render.yaml` and show the services (PostgreSQL + Web Service). Confirm and click **Apply**.
4. Add your **RAILS_MASTER_KEY**:
   - Open the **long-shot-web** service → **Environment**.
   - Add env var: `RAILS_MASTER_KEY` = value from `config/master.key` (or from your team). Mark as **Secret**.
5. (Optional) Add **BALLDONTLIE_API_KEY** for the PGA API in the same Environment section.
6. Save. Render will build and deploy. The app will be available at `https://long-shot-web.onrender.com` (or the URL shown in the dashboard).

### Option B: Manual setup

1. **New** → **PostgreSQL**. Name it e.g. `long-shot-db`, choose plan (Free is fine to start). Create.
2. **New** → **Web Service**. Connect the long_shot repo.
3. Configure:
   - **Build Command:** `bundle install && bundle exec rails tailwindcss:build && bundle exec rails assets:precompile && bundle exec rails assets:clean`
   - **Start Command:** `./bin/rails db:prepare && ./bin/rails server`
   - **Health Check Path:** `/up`
4. In **Environment**, add:
   - `RAILS_ENV` = `production`
   - `RAILS_MASTER_KEY` = (from `config/master.key`, secret)
   - `DATABASE_URL` = **from database** (use the internal URL from your PostgreSQL service)
   - `BALLDONTLIE_API_KEY` = (your API key, if needed)
   - `WEB_CONCURRENCY` = `2`
   - `SOLID_QUEUE_IN_PUMA` = `true`
5. Create Web Service. After deploy, note the service URL (e.g. `https://long-shot-web.onrender.com`).

---

## 2. Add Custom Domain in Render

1. Open your **Web Service** (e.g. long-shot-web) on Render.
2. Go to **Settings** → **Custom Domains**.
3. Click **Add Custom Domain** and enter your domain (e.g. `www.yourdomain.com` or `yourdomain.com`).
4. Render will show the DNS records you need. You’ll use one of:
   - **CNAME** for `www` (or subdomain) → e.g. `long-shot-web.onrender.com`
   - **A record** for root domain (`yourdomain.com`) → IP: `216.24.57.1`
5. Leave this tab open; you’ll add these in Green Geeks next.

---

## 3. Configure DNS at Green Geeks

1. Log in to **Green Geeks** and open **cPanel** (or your domain/DNS management).
2. Open **Zone Editor** (under **DOMAINS** or **Advanced**).
3. Add the records Render showed:

   **If using `www.yourdomain.com`:**
   - Type: **CNAME**
   - Name: `www` (or the subdomain you chose)
   - Target: your Render hostname, e.g. `long-shot-web.onrender.com`
   - TTL: 300 (or 3600)

   **If using root domain `yourdomain.com`:**
   - Type: **A**
   - Name: `@` (or leave blank for root)
   - Value: `216.24.57.1`
   - TTL: 300 (or 3600)

   **Optional:** Add both so `yourdomain.com` and `www.yourdomain.com` work (A for root, CNAME for www).

4. Remove any **AAAA** records for the same name if present (Render uses IPv4).
5. Save. DNS can take a few minutes to propagate (up to 48 hours in rare cases).

---

## 4. Set APP_HOST in Render (for custom domain)

So the app accepts requests to your domain and generates correct URLs:

1. In Render, open your **Web Service** → **Environment**.
2. Add: **APP_HOST** = your domain, e.g. `yourdomain.com` or `www.yourdomain.com` (no `https://`).
3. Save. Render will redeploy; after that, links and redirects will use your domain.

---

## 5. Subpath (jaredmelnyk.com/longshot)

To serve the app at a subpath (e.g. `jaredmelnyk.com/longshot`):

1. In Render, open your **Web Service** → **Environment**.
2. Add: **RAILS_RELATIVE_URL_ROOT** = `/longshot`.
3. Save and redeploy.
4. Configure your proxy (e.g. Green Geeks) so that requests to `jaredmelnyk.com/longshot` and `jaredmelnyk.com/longshot/*` are forwarded to the Render web service URL. The path can be forwarded as-is or stripped depending on your proxy; Rails expects the request path to match the subpath when using `relative_url_root`.

---

## 6. SSL (HTTPS)

Render provides **free SSL** for custom domains. After DNS is correct, Render will issue a certificate automatically. In **Settings** → **Custom Domains**, the domain should show as secured. If it doesn’t, wait for DNS to propagate and check Render’s status.

---

## Summary checklist

- [ ] Repo connected to Render; `render.yaml` applied (or manual Web + PostgreSQL created).
- [ ] `RAILS_MASTER_KEY` and `DATABASE_URL` set; optional `BALLDONTLIE_API_KEY` added.
- [ ] App deploys and responds at the Render URL (e.g. `https://long-shot-web.onrender.com`).
- [ ] Custom domain added in Render (Settings → Custom Domains).
- [ ] CNAME (for www) or A record (for root) set in Green Geeks Zone Editor.
- [ ] `APP_HOST` set in Render to your domain.
- [ ] After DNS propagation, site loads over HTTPS at your domain.

For Render-specific details: [Render Docs – Custom Domains](https://render.com/docs/custom-domains), [Render Docs – Deploy Rails](https://docs.render.com/deploy-rails).  
For Green Geeks DNS: [Green Geeks – DNS (MX, CNAME, A)](https://www.greengeeks.com/support/article/how-do-i-change-dns-for-mx-cname-and-a-records/).
