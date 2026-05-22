# Deploy to your Railway project (run after: railway login)
$ErrorActionPreference = "Stop"

$PROJECT_ID = "5fd7093b-dab7-4273-94d4-1ebffce26ae3"
$ENVIRONMENT_ID = "6369e761-d8e1-449f-97bc-a26e0b899839"
$SERVICE_ID = "eb48edf3-1f50-4153-ac89-75045e9df8d5"

Write-Host "Checking Railway CLI auth..."
railway whoami | Out-Null

Write-Host "Linking to your Railway project..."
railway link --project $PROJECT_ID --environment $ENVIRONMENT_ID --service $SERVICE_ID

Write-Host "Adding MySQL (skip if already exists)..."
railway add --database mysql 2>$null

$secret = -join ((48..57) + (97..102) | Get-Random -Count 32 | ForEach-Object { [char]$_ })
Write-Host "Setting production environment variables..."
railway variable set APP_ENV=prod
railway variable set "APP_SECRET=$secret"
railway variable set MESSENGER_TRANSPORT_DSN=doctrine://default?auto_setup=0
railway variable set MAILER_DSN=null://null
railway variable set APP_SHARE_DIR=var/share

Write-Host "Generating public domain..."
railway domain 2>$null

$domain = (railway domain --json 2>$null | ConvertFrom-Json).domain
if ($domain) {
    railway variable set "DEFAULT_URI=https://$domain"
    Write-Host "DEFAULT_URI set to https://$domain"
}

Write-Host "Deploying..."
railway up --detach

Write-Host ""
Write-Host "Dashboard: https://railway.com/project/$PROJECT_ID/service/$SERVICE_ID?environmentId=$ENVIRONMENT_ID"
Write-Host "Open app: railway open"
