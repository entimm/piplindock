include .env

MYSQL_CONTAINER = $(shell docker-compose ps -q mysql)
PIPLINPHP_CONTAINER = $(shell docker-compose ps -q piplin-php)

DATE = $(shell date +%y%m%d-%H%M%S)

DUMPS_PATH = $(shell pwd)/data/dumps
BACKUPS_PATH = $(shell pwd)/data/backups

SOURCE ?= latest

list:
	@echo ""
	@echo "usage: make COMMAND"
	@echo ""
	@echo "Commands:"
	@echo "  list"
	@echo "  mysql-dump"
	@echo "  mysql-load"
	@echo "  mysql-backup"
	@echo "  mysql-restore"
	@echo "  nginx-t"
	@echo "  nginx-reload"
	@echo "  fpm-restart"
	@echo "  cron-update"
	@echo "  clean"
	@echo "  logs"
	@echo "  supervisor-reload"
	@echo "  supervisor-status"
	@echo "  config-pull"
	@echo "  config-push"

mysql-dump:
	@mkdir -p $(DUMPS_PATH)
	@docker exec $(MYSQL_CONTAINER) mysqldump --all-databases -u"root" -p"$(MYSQL_ROOT_PASSWORD)" > $(DUMPS_PATH)/$(DATE).sql 2>/dev/null
	@ln -nfs $(DUMPS_PATH)/$(DATE).sql $(DUMPS_PATH)/$(SOURCE).sql

mysql-load:
	@docker exec -i $(MYSQL_CONTAINER) mysql -u"root" -p"root" < $(DUMPS_PATH)/$(SOURCE).sql 2>/dev/null

mysql-backup:
	@mkdir -p $(BACKUPS_PATH)
	@docker run --rm --volumes-from $(MYSQL_CONTAINER) -v $(BACKUPS_PATH):/backup busybox tar cvf /backup/$(DATE).tar /var/lib/mysql
	@ln -nfs $(BACKUPS_PATH)/$(DATE).tar $(BACKUPS_PATH)/$(SOURCE).tar

mysql-restore:
	@docker run --rm --volumes-from $(MYSQL_CONTAINER) -v $(BACKUPS_PATH):/backup busybox sh -c "cd /var/lib/mysql && tar xvf /backups/$(SOURCE).tar --strip 1"

nginx-t:
	@docker-compose exec nginx nginx -t

nginx-reload:
	@docker-compose exec nginx nginx -s reload

fpm-restart:
	@docker-compose restart piplin-php

cron-update:
	@docker cp ./piplin-php/crontab/* $(PIPLINPHP_CONTAINER):/etc/cron.d
	@docker-compose exec piplin-php chmod -R 644 /etc/cron.d

clean:
	@rm -Rf ./data/mysql/*

logs:
	@docker-compose logs -f

supervisor-reload:
	@docker-compose exec piplin-php supervisorctl reload

supervisor-status:
	@docker-compose exec piplin-php supervisorctl status

config-pull:
	@rsync -az -e 'ssh -A' ${SYNC_SERVER_USER}@${SYNC_SERVER_ADDR}:${SYNC_SERVER_PATH}/nginx/sites/* ./nginx/sites
	@rsync -az -e 'ssh -A' ${SYNC_SERVER_USER}@${SYNC_SERVER_ADDR}:${SYNC_SERVER_PATH}/piplin-php/supervisord.d/* ./piplin-php/supervisord.d

config-push:
	@rsync -az -e 'ssh -A' ./nginx/sites/* ${SYNC_SERVER_USER}@${SYNC_SERVER_ADDR}:${SYNC_SERVER_PATH}/nginx/sites
	@rsync -az -e 'ssh -A' ./piplin-php/supervisord.d/* ${SYNC_SERVER_USER}@${SYNC_SERVER_ADDR}:${SYNC_SERVER_PATH}/piplin-php/supervisord.d

.PHONY: logs nginx

