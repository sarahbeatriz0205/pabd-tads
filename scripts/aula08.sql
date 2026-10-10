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

-- ==================================================
-- Exemplo 4 - AFTER UPDATE
-- ==================================================

