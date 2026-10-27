-- Questão 1: Cadastro de Cliente e Perfil
begin;
-- erro: store_id inexistente
insert into customer (store_id, first_name, last_name, email, address_id) values (9999, 'Gustavo', 'Nascimento', 'sarah@email.com', 9999)
returning customer_id;
rollback;
insert into customer (store_id, first_name, last_name, email, address_id) values (1, 'Gustavo', 'Nascimento', 'sarah@email.com', 1)
returning customer_id;
select customer_id, first_name from customer where last_name = 'Nascimento';
commit;

-- Questão 2: Gestão de Estoque e Suprimentos
begin;
savepoint estoque_atualizado;
-- registro inválido
insert into inventory (film_id, store_id) values (1001, 1);
-- volta para o savepoint
rollback to estoque_atualizado;
-- registro válido
insert into inventory (film_id, store_id) values (1, 1);
commit;