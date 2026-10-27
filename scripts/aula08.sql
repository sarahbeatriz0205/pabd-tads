/* Triggers */
-- Dispara uma ação a partir de um determinado evento

CREATE FUNCTION nome_function()
   RETURNS TRIGGER
   LANGUAGE PLPGSQL -- pode usar qualquer linguagem suportava pelo postgresql
AS $$
BEGIN
   -- trigger logic
END;
$$

-- $$: início e fim de um bloco

CREATE TRIGGER trigger_name -- nome do trigger
   {BEFORE | AFTER} { event } -- {BEFORE | AFTER}: se vai acontecer antes ou depois do evento / { event }: evento que vai disparar esse trigger
   ON table_name -- tabela onde vai ser executado
   [FOR [EACH] { ROW | STATEMENT }]
       EXECUTE PROCEDURE nome_function -- executa a função criada

-- AFTER INSERT
drop table if exists customer_spending;
create table customer_spending (
    customer_id int primary key references customer(customer_id), 
    total numeric not null default 0
);

insert into customer_spending (customer_id, total)
select customer_id, sum(amount)
from payment
group by customer_id;

create or replace function update_customer_spending() 
returns trigger language PLPGSQL
as $$
    begin 
        update customer_spending set total = total + NEW.amount where customer_id = NEW.customer_id;
        return NEW;
    end
   $$;

drop trigger if exists trigger_update_customer_spending on payment;
create trigger trigger_update_customer_spending after insert on payment for each row execute function update_customer_spending();

select * from customer_spending where customer_id = 1;

insert into payment (customer_id, staff_id, rental_id, amount, payment_date)
values (1, 1, 1, 10, now());

select * from customer_spending where customer_id = 1;

-- ==================================================
-- Exemplo 2 - BEFORE INSERT
-- ==================================================

-- Validação de regra de negócio (rental_date não pode ser no futuro)

create or replace function check_rental_date()
    returns trigger
    language plpgsql
as $$
begin
    if NEW.rental_date > now() then
        raise exception 'rental_date no futuro!? (valor recebido: %)', NEW.rental_date;
    end if;

    return NEW;
end;
$$;

drop trigger if exists trg_check_rental_date on rental;
create trigger trg_check_rental_date
before insert on rental
for each row
execute function check_rental_date();

-- Teste
insert into rental (rental_date, inventory_id, customer_id, staff_id)
values (now() + interval '1 day', 1, 1, 1);

select count(*) from rental;

-- ==================================================
-- Exemplo 3 - BEFORE UPDATE
-- ==================================================

-- validação: rental_rate não pode ser negativo
create or replace function check_rental_rate()
    returns trigger
    language plpgsql
    as $$
        begin
            if NEW.rental_rate < 0 then 
                raise exception 'negativo, pai? pode não (valor recebido: %)', NEW.rental_rate;
            end if;
        end;
       $$;

drop trigger if exists trigger_check_rental_rate on film;
create trigger trigger_check_rental_rate before update of rental_rate on film
for each row execute function check_rental_rate();

update film set rental_rate = -5 where film_id = 1;
select rental_rate from film where film_id = 1;

-- Auditoria de alterações salariais
drop table if exists audit_salary_changes;
create table audit_salary_changes (
    id serial primary key,
    cpf_funcionario char(11) not null references funcionario(cpf),
    old_salario numeric(7, 2),
    new_salario numeric(7, 2),
    change_date timestamptz default now(),
    change_percent numeric(7, 2)
);

create or replace function log_salary_changes()
    returns trigger
    language plpgsql
as $$
declare
    -- variable_name type;
    -- variable_name table_name.column_name%type;
    -- percent audit_salary_changes.change_percent%type;
    percent numeric(7, 2);
begin
    if NEW.salario != OLD.salario then
        percent = ((NEW.salario - OLD.salario) / OLD.salario) * 100;

        insert into audit_salary_changes (cpf_funcionario, old_salario, new_salario, change_percent)
        values (NEW.cpf, OLD.salario, NEW.salario, percent);
    end if;

    return new;
end;
$$;

drop trigger if exists trg_log_salary_changes on funcionario;
create trigger trg_log_salary_changes
after update on funcionario
for each row
execute function log_salary_changes();

-- Teste
select * from audit_salary_changes;

update funcionario set salario = 15000 where cpf = '11122233344';

update funcionario set salario = 14995 where cpf = '22233344455';

update funcionario set salario = 4995 where cpf = '22233344455';

-- Uso de WHEN
create or replace function log_salary_changes_when()
    returns trigger
    language plpgsql
as $$
declare -- declaração de variáveis em plpgsql
    -- variable_name type;
    -- variable_name table_name.column_name%type;
    -- percent audit_salary_changes.change_percent%type;
    percent numeric(7, 2);
begin
    percent = ((NEW.salario - OLD.salario) / OLD.salario) * 100;

    insert into audit_salary_changes (cpf_funcionario, old_salario, new_salario, change_percent)
    values (NEW.cpf, OLD.salario, NEW.salario, percent);

    return new;
end;
$$;

drop trigger if exists trg_log_salary_changes_when on funcionario;
create trigger trg_log_salary_changes_when
after update on funcionario
for each row
when (NEW.salario != OLD.salario) -- gatilho condicional: se for verdadeiro, executa a função
execute function log_salary_changes_when();

-- ==================================================
-- Exemplo 5 - BEFORE DELETE
-- ==================================================

-- Manutenção de integridade referencial (impedir a exclusão de cliente com pagamentos)
create or replace function prevent_customer_del()
    returns trigger
    language plpgsql
as $$
begin
    if exists (select 1 from payment where customer_id = OLD.customer_id) then
        raise exception 'Não permitido excluir clientes com pagamentos (customer_id: %)', OLD.customer_id;
    end if;

    return old;
end;
$$;

drop trigger if exists trg_prevent_customer_del on customer;
create trigger trg_prevent_customer_del
before delete on customer
for each row
execute function prevent_customer_del();

-- Teste
delete from customer where customer_id = 1;

-- Triggers INSTEAD OF: gatilhos especiais que interceptam ações das views

-- ==================================================
-- Exemplo 5 - INSTEAD OF
-- ==================================================

