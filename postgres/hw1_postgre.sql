create schema std_hw;

drop table if exists std_hw.users
truncate table std_hw.users
CREATE TABLE std_hw.users (
    id SERIAL PRIMARY KEY,
    name TEXT,
    email TEXT,
    role TEXT,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

drop table if exists std_hw.users_audit
CREATE TABLE std_hw.users_audit (
    id SERIAL PRIMARY KEY,
    user_id INTEGER,
    changed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    changed_by TEXT,
    field_changed TEXT,
    old_value TEXT,
    new_value TEXT
);
--Логировать все изменения пользователей (name, email, role)
--Техническое задание.
--1. Создайте функцию логирования изменений по трем полям.
--2. Создайте trigger на таблицу users.
--3. Установите расширение pg_cron.
--4. Создайте функцию, которая будет доставать только свежие данные (за сегодняшний день)
-- и будет сохранять их в образе Docker по пути /tmp/users_audit_export_,
-- а далее указываете ту дату, за который этот csv был создан.
--5. Установите планировщик pg_cron на 3:00 ночи.

create or replace function std_hw.log_users_update()
returns trigger
as 
$$ begin
	if new.name is distinct from old.name then
		insert into std_hw.users_audit (user_id, field_changed, old_value, new_value, changed_by)
		values (old.id, 'name', old.name, new.name, current_user);
	end if;
	if new.email is distinct from old.email then
		insert into std_hw.users_audit (user_id, field_changed, old_value, new_value, changed_by)
		values (old.id, 'email', old.email, new.email, current_user);
	end if;
	if new.role is distinct from old.role then
		insert into std_hw.users_audit (user_id, field_changed, old_value, new_value, changed_by)
		values (old.id, 'role', old.role, new.role, current_user);
	end if;

	return new;
end; 
$$ language plpgsql;

create trigger trigger_log_users_audit
before update on std_hw.users 
for each row
execute function std_hw.log_users_update();

INSERT INTO std_hw.users (name, email, role)
VALUES ('Ivan Ivanov', 'ivan@example.com', 'user');

update std_hw.users set name = 'Alex Smith', email = 'alice.smith@example.com' where id = 1

-- создаем функцию ежедневной отправки отчета по логированию users

create or replace function std_hw.export_audit_to_csv()
returns void
as 
$outer$
declare
--	path text:= format($$'/tmp/users_audit_export_%s.csv'$$, to_char(NOW(), 'YYYYMMDD_HH24MI'));
	path text:= '/tmp/users_audit_export_'||to_char(NOW(), 'YYYYMMDD_HH24MI')||'.csv';
begin
	execute format(
		$inner$
		copy (
			select user_id, field_changed, old_value, new_value, changed_by, changed_at
			from std_hw.users_audit
			where changed_at >= now() - interval '1 day'
		) to '%s' with csv header
		$inner$, path
	);
end;
$outer$
language plpgsql;

select std_hw.export_audit_to_csv()
--------------------------
select cron.schedule(
	job_name := 'daily_audit_export',
	schedule := '0 19 * * *',
	command := $$select std_hw.export_audit_to_csv();$$
);

CREATE EXTENSION IF NOT exists

select* from cron.job
-- посмотреть версию postgre: dpkg -l | grep postgresql
-- через терминал попадаем в наш докер:
-- docker exec -it postgres_db bash