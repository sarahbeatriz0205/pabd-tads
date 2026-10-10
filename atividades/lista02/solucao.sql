/* Lista de exercícios 02 */

-- Questão 01 - View de Performance da Equipe
drop view if exists v_staff_perfomance;
create view v_staff_perfomance as
select 
    s.staff_id funcionario_id, 
    s.first_name || ' ' || s.last_name nome_completo, 
    c.city cidade, 
    co.country pais,
    r.qtd_vendas_registradas,
    p.valor_total
    from staff s
    left join (select staff_id, count(rental_id) qtd_vendas_registradas from rental group by staff_id) r on r.staff_id = s.staff_id
    left join (select staff_id, sum(amount) valor_total from payment group by staff_id) p on p.staff_id = s.staff_id
    join address a on s.address_id = a.address_id
    join city c on c.city_id = a.city_id
    join country co on c.country_id = co.country_id
    group by s.staff_id, s.first_name, s.last_name, c.city, co.country, r.qtd_vendas_registradas, p.valor_total;

select * from v_staff_perfomance;


-- Questão 02 - View Materializada de Receita por Categoria
drop materialized view if exists mv_category_total_sales;
create materialized view mv_category_total_sales as
select cat.name, sum(p.receita) from film_category fc 
    join category cat on cat.category_id = fc.category_id
    join inventory i on fc.film_id = i.film_id
    join rental r on r.inventory_id = i.inventory_id
    join (select rental_id, sum(amount) receita from payment group by rental_id) p on p.rental_id = r.rental_id
    group by cat.name;

create unique index idx_mv_category_total_sales on mv_category_total_sales(name);

select * from mv_category_total_sales;

-- Questão 03 - Otimizando Filmes Atrasados
create index idx_check_open_rentals on rental(return_date) where return_date is null;

-- Questão 04 - Busca Inteligente de Sinopses

-- Questão 05 - Histórico do Cliente
create index idx_check_history on payment(customer_id, payment_date);

-- Questão 06 - Login Case-Insensitive
create index idx_login_case_sensitive on customer(lower(email));
select first_name || '' || last_name nome, email from customer where lower(email) = lower('MARY.SMITH@SAKILACUSTOMER.ORG');

-- Questão 07 - Validação de Datas
create or replace function check_return_date()
    returns trigger
    language plpgsql as 
    $$
    begin
        if NEW.return_date is not null and NEW.return_date < NEW.rental_date then
            raise exception 'data de retorno menor que a data da locação não existe, está errado. valor:%', NEW.return_date;
        end if;
        return NEW;
    end;
    $$;

drop trigger if exists trg_check_return_date on rental;
create trigger trg_check_return_date before insert or update on rental
for each row execute function check_return_date();
