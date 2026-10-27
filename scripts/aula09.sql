/* Transações */

-- Toda instrução é executada dentro de uma transação
-- É com se fosse uma espécie de camada de validação
-- Propriedades ACID
    -- Atomicidade: todas as instruções são gravadas com sucesso ou então nada é gravado. 
        -- Exige que uma transação seja executada até o fim, e se der problema, o banco deve recuperar o que foi feito 
        -- até o problema e desfazer qualquer alteração
    
    -- Consistência: o banco transita de um estado pra outro 
        -- rollback
        -- Estado: coleção de todos os valores armazenados no banco em determinado ponto no tempo
        -- Safe point: Guarda o estado anterior do banco. Anterior à transação, pra que caso dê errado, o banco possa voltar ao anterior
    
    -- Isolamento: Transações simultâneas não devem interferir em outras
        -- Controle de concorrência

    -- Durabilidade: Uma vez confirmada, a alteração é permanente

-- Sintaxe
begin; 
-- a partir daqui (begin), todo comando DML que vier, fará parte de um transação e será monitorado


commit; -- pra desfazer: rollback;
-- commit: final da transação. efetua a transação

-- Ex1: Aluguel
begin;
insert into rental (rental_date, inventory_id, customer_id, staff_id) values (now(), 1, 1, 1)
returning rental_id;

insert into payment (customer_id, staff_id, rental_id, amount, payment_date) values (1, 1, currval('rental_rental_id_seq'), 4.99, now())
returning payment_id;
commit;