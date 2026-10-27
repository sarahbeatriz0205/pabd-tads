-- Questão 1 - Resumo por piloto/temporada

-- falta a qtd total de pontos, ficou todo bugado quando eu tentei
drop materialized view if exists mv_driver_season_summary;
create materialized view mv_driver_season_summary as 
    select r.year, 
           d.name, 
           d.total_race_entries total_corridas, 
           count(case when rd.position_number = 1 then 1 end) total_vitorias, 
           count(case when rd.position_number <= 3 then 1 end) total_podios,
           count(case when rd.race_reason_retired is not null then 1 end) total_abandonos
           from driver d
           join race_data rd on rd.driver_id = d.id
           join race r on r.id = rd.race_id
           where d.name = 'Ayrton Senna'
           group by r.year, d.name, d.total_race_entries order by r.year limit 10; 

drop index if exists idx_mv_driver_season_summary;
create unique index idx_mv_driver_season_summary on mv_driver_season_summary(year);
refresh materialized view concurrently mv_driver_season_summary;

select * from mv_driver_season_summary; 

-- Questão 2 - Auditoria de pontos do campeonato

DROP TABLE IF EXISTS points_adjustment_audit;
CREATE TABLE points_adjustment_audit (
    id         SERIAL PRIMARY KEY,
    year       INT NOT NULL,
    driver_id  VARCHAR(100) NOT NULL,
    old_points DECIMAL(8,2),
    new_points DECIMAL(8,2),
    changed_at TIMESTAMPTZ DEFAULT NOW()
);

create or replace function checar_mudanca_pontos() 
    returns trigger
    language plpgsql as
    $$
    begin
        if NEW.points != OLD.points then   
            update points_adjustment_audit set new_points = NEW.points;
        end if;

        return NEW;
    end;
    $$;

create trigger trg_checar_mudanca_pontos 
after update on season_driver_standing 
for each row
when (NEW.points != OLD.points)
execute function checar_mudanca_pontos();

-- Questão 3 - Impedir exclusão de piloto com histórico
create or replace function impede_exclusao_piloto()
    returns trigger
    language plpgsql as
    $$
    begin
        if exists (select 1 from race_data where driver_id = OLD.id) then
            raise exception 'Piloto não pode ser excluído! %', OLD.name;
        end if;
    end;
    $$;

create trigger trg_impede_exclusao_piloto
before delete on driver 
for each row 
execute function impede_exclusao_piloto();