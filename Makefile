.PHONY: db-up db-setup db-seed db-status db-analises db-test db-logs db-down db-reset

db-up:
	docker compose up -d --wait database

db-setup: db-up
	docker compose run --rm --no-deps setup

db-seed: db-setup
	docker compose run --rm --no-deps seed

db-status:
	docker compose ps
	@docker compose exec -T database psql -X -U tabd_saude -d tabd_saude -c \
		"SELECT 'especialidades' AS tabela, COUNT(*) FROM especialidades UNION ALL SELECT 'pacientes', COUNT(*) FROM pacientes UNION ALL SELECT 'exames', COUNT(*) FROM exames UNION ALL SELECT 'consultas', COUNT(*) FROM consultas UNION ALL SELECT 'exames_solicitados', COUNT(*) FROM exames_solicitados ORDER BY tabela;"

db-analises:
	@for f in queries/*.sql; do \
		echo "== $$f"; \
		docker compose exec -T database psql -X -v ON_ERROR_STOP=1 \
			-U tabd_saude -d tabd_saude < "$$f"; \
	done

db-test:
	@docker compose exec -T database psql -X -U tabd_saude -d tabd_saude \
		< scripts/testes.sql

db-logs:
	docker compose logs -f database

db-down:
	docker compose down --remove-orphans

db-reset:
	docker compose down --volumes --remove-orphans
	$(MAKE) db-seed
