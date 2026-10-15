docker compose -f docker-compose-production.yml up --build -d
docker compose -f docker-compose-production.yml exec web bash
VISUAL="code --wait" bin/rails credentials:edit --environment development
