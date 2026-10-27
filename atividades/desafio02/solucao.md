# DESAFIO DE PROGRAMAÇÃO 02

## Questão 1: Cadastro de Cliente e Perfil

**Cenário:** Um novo cliente deseja se cadastrar no sistema. Para isso, ele precisa inserir seus dados básicos e um endereço de contato.

**Tarefas:**

1. Inicie uma transação para inserir um novo registro na tabela `customer`.
2. Tente inserir um dado obrigatório que viole uma regra.
3. Observe a falha do comando.
4. Execute ROLLBACK.

O cliente cadastrado no passo 1 ainda existe na tabela? Por que o banco de dados deve "esquecer" todo o processo se um detalhe do cadastro falhar?
> **Resposta:** O cliente cadastrado no passo 1 nem chegou a ser criado. Quando o erro foi disparado, a transação bloqueou minha instância do banco e não permitiu que fossem feitas outras operações. Ao dar rollback, a transação foi cancelada e o banco voltou ao estado anterior à transação e o cliente não foi criado. O banco deve "esquecer" (rollback) o processo caso haja falha para que ele fique no estado anterior, que estava em pleno funcionamento. Isso também garante que nenhuma informação errônea ou equivocada chegue ao banco, da mesma maneira que nenhuma informação importante seja deletada. 

~~~sql
-- Em SQL

begin;

-- erro: store_id inexistente e endereço inexistente
insert into customer (store_id, first_name, last_name, email, address_id) values (9999, 'Gustavo', 'Nascimento', 'sarah@email.com', 9999)
returning customer_id;

-- ao disparar o erro, cancela transação
rollback;

-- inserção funciona
insert into customer (store_id, first_name, last_name, email, address_id) values (1, 'Gustavo', 'Nascimento', 'sarah@email.com', 1)
returning customer_id;

select customer_id, first_name from customer where last_name = 'Nascimento';
commit;

/* 
ERRO NO TERMINAL:

BEGIN
ERROR:  insert or update on table "customer" violates foreign key constraint "customer_address_id_fkey"
DETAIL:  Key (address_id)=(9999) is not present in table "address".
ERROR:  current transaction is aborted, commands ignored until end of transaction block 
*/
~~~

---

## Questão 2: Gestão de Estoque e Suprimentos

**Cenário:** O gestor do estoque quer registrar a chegada de novos filmes e atualizar o status de disponibilidade.

**Tarefas:**

1. Inicie uma transação para inserir um novo registro na tabela `inventory`.
2. Execute um SAVEPOINT chamado *estoque_atualizado*.
3. Tente inserir uma entrada de inventário para um filme que não existe.
4. O comando falhará, mas você deve manter a inserção anterior.
5. Insira um registro de inventário válido e finalize com COMMIT.

Após o COMMIT, a tabela possui apenas o registro válido ou ambos? Qual é a vantagem de usar SAVEPOINT aqui em vez de desistir de todo o processo de atualização do estoque?
> **Resposta:** Após o COMMIT, a tabela possui apenas o registro válido, uma vez que a transação foi travada e disparou o erro, cancelando assim o comando. Para não precisar cancelar a transação e começar "tudo de novo", o SAVEPOINT foi crucial. A vantagem de utilizar o SAVEPOINT é que ele permite que você volte a transação de um ponto específico, sem precisar cancelar a transação inteira.

~~~sql
-- Em SQL
begin;
savepoint estoque_atualizado;
-- registro inválido
insert into inventory (film_id, store_id) values (1001, 1);
-- volta para o savepoint
rollback to estoque_atualizado;
-- registro válido
insert into inventory (film_id, store_id) values (1, 1);
commit;

/* TERMINAL 
dvdrental=# begin;
BEGIN
insert into inventory (film_id, store_id) values (1001, 1);
ERROR:  insert or update on table "inventory" violates foreign key constraint "inventory_film_id_fkey"
DETAIL:  Key (film_id)=(1001) is not present in table "film".
dvdrental=!# rollback to estoque_atualizado;
ROLLBACK
dvdrental=*# insert into inventory (film_id, store_id) values (1, 1);
INSERT 0 1
dvdrental=*# commit;
COMMIT
*/
~~~

---

## Questão 3: Concorrência na Gestão de Estoque e Suprimentos

**Cenário:** Na operação logística da locadora, dois gestores de suprimentos estão tentando processar o mesmo item físico de estoque (mesmo `inventory_id`) exatamente ao mesmo tempo. Um gestor está tentando transferir a unidade recém cadastrada para a outra loja para suprir uma demanda, enquanto o outro está tentando excluí-la pois afirma ter que devolver ao distribuidor devido a um erro na emissão da nota fiscal de aquisição.

Simule uma transação concorrente para mostrar em sessões diferentes as ações de cada gestor. O que iniciar primeiro a transação terá prioridade. Mostre um passo-a-passo considerando se a sessão A iniciar primeiro e outro considerando a sessão B.