# ApiVault CLI Sample Automation & Workflows (PowerShell)

$ErrorActionPreference = "Stop"

Write-Host "==> 1. Check current session"
apivault whoami

Write-Host "==> 2. Add an encrypted API key non-interactively"
apivault keys add `
  --name "STRIPE_SECRET_KEY" `
  --service "Stripe" `
  --environment "Production" `
  --key "sk_live_510exampleMockKey0001" `
  --notes "Automated provisioning"

Write-Host "==> 3. List masked keys in JSON format"
apivault --json keys list

Write-Host "==> 4. Set local project defaults"
apivault config set run.env "Production"
apivault config set run.command "npm start"

Write-Host "==> 5. Inject secrets into a local process (no .env on disk)"
apivault run -- npm start

Write-Host "==> 6. Export dotenv for tools requiring disk configuration"
apivault env export --env "Production" -o .env.production --force
