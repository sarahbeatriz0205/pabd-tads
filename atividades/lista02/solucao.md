# Lista de Exercícios 2 - Views, Indexes e Triggers

## Questão 01 - View de Performance da Equipe

A gerência quer um painel rápido para avaliar o desempenho dos funcionários. Crie uma view chamada `v_staff_performance` que exiba:

- `staff_id` e o nome completo do funcionário;
- endereço (cidade + país) onde a loja dele está localizada;
- A quantidade total de locações (`rentals`) processadas por ele;
- O valor total arrecadado através dos pagamentos que ele registrou.

### Solução da questão 01
~~~sql
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

-- Como comprovar
select * from v_staff_perfomance;
~~~

## Questão 02 - View Materializada de Receita por Categoria
O relatório de receita por categoria de filme é muito pesado, pois exige cruzar category, film_category, inventory, rental e payment. Crie uma Materialized View chamada mv_category_total_sales que liste o nome da categoria e o total de receita gerado por ela. Crie um índice único na MV que permita que ela seja atualizada de forma não-bloqueante (CONCURRENTLY). Escreva o comando SQL para recarregar os dados da MV sem bloquear as consultas dos usuários do sistema.

### Solução da questão 02
~~~sql
create materialized view mv_category_total_sales as
select cat.name, sum(p.receita) from film_category fc 
    join category cat on cat.category_id = fc.category_id
    join inventory i on fc.film_id = i.film_id
    join rental r on r.inventory_id = i.inventory_id
    join (select rental_id, sum(amount) receita from payment group by rental_id) p on p.rental_id = r.rental_id
    group by cat.name;

-- Index
create unique index idx_mv_category_total_sales on mv_category_total_sales(name);

-- Como comprovar
select * from mv_category_total_sales;
~~~

## Questão 03 - Otimizando Filmes Atrasados

O sistema de cobrança roda a cada hora buscando locações que ainda não foram devolvidas (`return_date IS NULL`) para calcular multas. Como a tabela `rental` é grande e a maioria dos filmes já foi devolvida, um *Seq Scan* é muito caro. Crie um índice (parcial?) na tabela `rental` que indexe apenas as locações em aberto. Em seguida, escreva a consulta e use o `EXPLAIN ANALYZE` para provar que o índice está sendo utilizado.

### Solução da questão 3
~~~sql
create index idx_check_open_rentals on rental(return_date) where return_date is null;

/*  ---- Consulta sem índice ----                                                        
 Seq Scan on rental  (cost=10000000000.00..10000000310.44 rows=183 width=4) (actual time=11.877..12.051 rows=183 loops=1)
   Filter: (return_date IS NULL)
   Rows Removed by Filter: 15861
 Planning Time: 0.065 ms
 JIT:
   Functions: 4
   Options: Inlining true, Optimization true, Expressions true, Deforming true
   Timing: Generation 0.287 ms, Inlining 0.029 ms, Optimization 6.949 ms, Emission 4.372 ms, Total 11.637 ms
 Execution Time: 12.391 ms */

/*   ---- Consulta com índice ----                              
 Index Scan using idx_check_open_rentals on rental  (cost=0.14..37.45 rows=183 width=4) (actual time=0.022..0.084 rows=183 loops=1)
 Planning Time: 0.202 ms
 Execution Time: 0.126 ms */ 
~~~

## Questão 04 - Busca Inteligente de Sinopses

Os clientes reclamam que a busca por palavras-chave na descrição dos filmes (`description`) usando `LIKE '%palavra%'` está lenta e não encontra variações da palavra (ex: "act", "acting", "actor"). Crie um índice adequado para melhorar o desempenho na busca. Em seguida, escreva uma consulta par buscar *documentary* e *drama* na descrição. Use o `EXPLAIN ANALYZE` para provar que o índice está sendo utilizado.

## Questão 05 - Histórico do Cliente

Sempre que o cliente abre seu perfil no aplicativo, o sistema busca o histórico de pagamentos dele, ordenados do mais recente para o mais antigo:

`SELECT * FROM payment WHERE customer_id = X ORDER BY payment_date DESC`.

Para otimizar essa consulta específica, crie um índice multicoluna na tabela `payment`. Qual coluna deve vir primeiro no índice e por quê?
**Resposta:** 
~~~sql
create index idx_check_history on payment(customer_id, payment_date);
~~~

## Questão 06 - Login Case-Insensitive

O suporte técnico frequentemente busca clientes pelo e-mail, mas os atendentes não se preocupam com letras maiúsculas ou minúsculas (ex: buscam por `MARY.SMITH@...` quando o e-mail está gravado como `mary.smith@...`). Crie um **Índice Funcional** (Expression Index) na tabela `customer` que permita buscas rápidas e *case-insensitive* na coluna `email`. Crie uma consulta usando `EXPLAIN ANALYZE` para provar que o índice está sendo utilizado.
~~~sql
create index idx_login_case_sensitive on customer(lower(email));
select first_name || '' || last_name nome, email from customer where lower(email) = lower('MARY.SMITH@SAKILACUSTOMER.ORG');

/*   Bitmap Heap Scan on customer  (cost=4.30..11.16 rows=3 width=64) (actual time=0.071..0.072 rows=1 loops=1)
   Recheck Cond: (lower((email)::text) = 'mary.smith@sakilacustomer.org'::text)
   Heap Blocks: exact=1
   ->  Bitmap Index Scan on idx_login_case_sensitive  (cost=0.00..4.30 rows=3 width=0) (actual time=0.063..0.063 rows=1 loops=1)
         Index Cond: (lower((email)::text) = 'mary.smith@sakilacustomer.org'::text)
 Planning Time: 0.179 ms
 Execution Time: 0.091 ms */
~~~

## Questão 07 - Validação de Datas

Ocorreu um bug no front-end que permitiu inserir locações onde a data de devolução (`return_date`) era *anterior* à data de locação (`rental_date`), gerando multas negativas. Crie um trigger `BEFORE INSERT OR UPDATE` na tabela `rental` que lance uma exceção (`RAISE EXCEPTION`) caso o `NEW.return_date` seja menor que o `NEW.rental_date`. Lembre-se de tratar o caso onde o `return_date` é `NULL` (o filme ainda está com o cliente). Realize 2 consultas teste para validar (sucesso/falha)

~~~sql
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
~~~