# The TaskMate Project

## Run
```bash
docker compose up -d --build nginx postgres valkey src_laravel_api src_telegram_bot_api src_vanilla_flow_telegram_bot_api pgadmin --force-recreate
```

## Create SSL Certificate
```bash
docker compose run --rm certbot certonly --webroot   --webroot-path=/var/www/certbot   --email you@example.com   --agree-tos --no-eff-email   -d taskmate.andcrm.ru -d telegram.taskmate.andcrm.ru -d vanilla.taskmate.andcrm.ru
```
