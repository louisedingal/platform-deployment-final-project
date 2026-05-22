# Railway Deployment Guide

Your Railway project:
- **Project:** `5fd7093b-dab7-4273-94d4-1ebffce26ae3`
- **Service:** `eb48edf3-1f50-4153-ac89-75045e9df8d5`
- **Environment:** `6369e761-d8e1-449f-97bc-a26e0b899839`
- **Dashboard:** https://railway.com/project/5fd7093b-dab7-4273-94d4-1ebffce26ae3/service/eb48edf3-1f50-4153-ac89-75045e9df8d5?environmentId=6369e761-d8e1-449f-97bc-a26e0b899839

## Architecture

- **Production (Railway):** Single Docker container with nginx + PHP-FPM. Railway sets `PORT`; nginx listens on that port.
- **Local dev:** `docker-compose.yaml` uses separate `app` and `nginx` containers.

## Required variables (Railway → Variables)

| Variable | Value |
|----------|-------|
| `APP_ENV` | `prod` |
| `APP_SECRET` | 32+ char random secret (generate with `openssl rand -hex 16`) |
| `DATABASE_URL` | Reference from MySQL service: `${{MySQL.MYSQL_URL}}` or Railway’s provided URL |
| `DEFAULT_URI` | Your public URL, e.g. `https://your-app.up.railway.app` |
| `MESSENGER_TRANSPORT_DSN` | `doctrine://default?auto_setup=0` |
| `MAILER_DSN` | `null://null` |
| `APP_SHARE_DIR` | `var/share` |

### MySQL on Railway

1. In your project, add **MySQL** if not already added.
2. On your **app service** → Variables → add:
   - `DATABASE_URL` = `${{MySQL.MYSQL_URL}}`  
     (replace `MySQL` with your MySQL service name if different)

## Deploy options

### Option A — CLI (after `railway login`)

```powershell
.\deploy-railway.ps1
```

### Option B — GitHub (auto-deploy)

1. Push this repo to `origin/master`.
2. In Railway service settings, connect the GitHub repo `louisedingal/platform-deployment-final-project`.
3. Set root directory to `/` and builder to **Dockerfile**.
4. Redeploy from the dashboard.

### Option C — Manual upload

```powershell
railway login
railway link --project 5fd7093b-dab7-4273-94d4-1ebffce26ae3 --environment 6369e761-d8e1-449f-97bc-a26e0b899839 --service eb48edf3-1f50-4153-ac89-75045e9df8d5
railway up
```

## Troubleshooting

- **502 / app not responding:** Ensure `PORT` is used (nginx template) and PHP-FPM uses `127.0.0.1:9000`.
- **Database connection failed:** Link MySQL to the app service and set `DATABASE_URL`.
- **Migrations failed:** Check deploy logs; MySQL must be running before the app starts (entrypoint waits up to 60s).
