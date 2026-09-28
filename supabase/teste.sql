-- Teste do schema.sql num Postgres local (NÃO rodar no Supabase).
-- Simula o que o Supabase fornece (auth.users, auth.uid(), papéis anon/authenticated)
-- e verifica isolamento por unidade, permissões e ciclo de status.
-- Uso: psql -v ON_ERROR_STOP=1 -f supabase/teste.sql   (banco vazio)

\set QUIET on
create role anon nologin;
create role authenticated nologin;
create schema auth;
create schema extensions;
create table auth.users (id uuid primary key, email text unique);
create function auth.uid() returns uuid language sql stable
as $$ select nullif(current_setting('request.jwt.claim.sub', true), '')::uuid $$;
grant usage on schema public, auth, extensions to anon, authenticated;
alter default privileges in schema public grant all on tables to anon, authenticated;
alter default privileges in schema public grant all on sequences to anon, authenticated;
alter default privileges in schema public grant execute on functions to anon, authenticated;

\ir schema.sql

insert into auth.users values
  ('00000000-0000-0000-0000-00000000000a', 'gestor.a@teste'),
  ('00000000-0000-0000-0000-00000000000b', 'gestor.b@teste'),
  ('00000000-0000-0000-0000-00000000000c', 'secretaria@teste'),
  ('00000000-0000-0000-0000-00000000000d', 'semperfil@teste');
select vincular_usuario('gestor.a@teste', 'Gestora A', 'gestor', 'Escola A');
select vincular_usuario('gestor.b@teste', 'Gestor B', 'gestor', 'Escola B');
select vincular_usuario('secretaria@teste', 'Secretaria', 'secretaria', null);

\echo '--- gestor A'
set role authenticated;
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-00000000000a', false);
do $$
declare r solicitacoes;
begin
  -- tenta cadastrar para a escola B e já como "entregue": o banco corrige
  insert into solicitacoes (unidade_id, categoria, item, quantidade, status, justificativa)
  values ((select 2), 'limpeza_higiene', '  Pá de LIXO ', 3, 'entregue', 'x') returning * into r;
  assert r.unidade_id = (select id from unidades where nome = 'Escola A'), 'unidade forçada para a do gestor';
  assert r.status = 'cadastrada' and r.justificativa is null, 'status/campos da Secretaria zerados';
  assert r.item = 'Pá de LIXO' and r.item_busca = 'pa de lixo', 'item aparado e normalizado';
  insert into solicitacoes (categoria, item, quantidade) values ('tecnologia', 'Projetor', 1);
  assert (select count(*) from historico) = 2, 'histórico de cadastro';
  assert (select count(*) from unidades) = 1, 'gestor vê só a própria unidade';
  begin
    insert into solicitacoes (categoria, item, quantidade) values ('tecnologia', 'X', 0);
    assert false, 'quantidade 0 deveria falhar';
  exception when check_violation then null;
  end;
end $$;

\echo '--- gestor B'
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-00000000000b', false);
do $$
declare n int;
begin
  insert into solicitacoes (categoria, item, quantidade) values ('material_expediente', 'Papel A4', 10);
  assert (select count(*) from solicitacoes) = 1, 'B vê só a própria solicitação';
  assert (select count(*) from historico) = 1, 'B vê só o próprio histórico';
  assert (select sum(total) from contagem_por_status()) = 1, 'contagem respeita a unidade';
  update solicitacoes set status = 'em_analise';
  get diagnostics n = row_count;
  assert n = 0, 'gestor não altera status';
  select count(*) into n from perfis;
  assert n = 1, 'gestor vê só o próprio perfil';
end $$;

\echo '--- Secretaria'
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-00000000000c', false);
do $$
declare id_pa bigint := (select id from solicitacoes where item = 'Pá de LIXO');
begin
  assert (select count(*) from solicitacoes) = 3, 'Secretaria vê todas';
  begin
    insert into solicitacoes (categoria, item, quantidade) values ('tecnologia', 'X', 1);
    assert false, 'Secretaria não cadastra';
  exception when raise_exception then null;
  end;
  begin
    update solicitacoes set status = 'adquirida', quantidade_adquirida = 1 where id = id_pa;
    assert false, 'não pode pular etapa';
  exception when raise_exception then null;
  end;
  update solicitacoes set status = 'em_analise', item = 'alterado' where id = id_pa;
  assert (select item from solicitacoes where id = id_pa) = 'Pá de LIXO', 'item não muda';
  begin
    update solicitacoes set status = 'nao_atendida' where id = id_pa;
    assert false, 'não atendida exige justificativa';
  exception when raise_exception then null;
  end;
  begin
    update solicitacoes set status = 'adquirida' where id = id_pa;
    assert false, 'adquirida exige quantidade';
  exception when raise_exception then null;
  end;
  update solicitacoes set status = 'adquirida', quantidade_adquirida = 2, previsao_entrega = '2026-10-10' where id = id_pa;
  update solicitacoes set status = 'entregue' where id = id_pa;
  begin
    update solicitacoes set status = 'em_analise' where id = id_pa;
    assert false, 'estado final não volta';
  exception when raise_exception then null;
  end;
  assert (select count(*) from historico where solicitacao_id = id_pa) = 4, 'histórico com 4 status';
  assert (select alterado_por_nome from historico where solicitacao_id = id_pa order by id desc limit 1) = 'Secretaria', 'nome no histórico';
  assert (select count(*) from novidades) = 0, 'Secretaria não vê novidades';
end $$;

\echo '--- avisos (novidades)'
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-00000000000b', false);
do $$
declare n int;
begin
  delete from novidades;
  get diagnostics n = row_count;
  assert n = 0, 'B não apaga aviso da escola A';
end $$;
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-00000000000a', false);
do $$
begin
  assert (select count(*) from novidades) = 1, 'A tem 1 aviso';
  delete from novidades;
  assert (select count(*) from novidades) = 0, 'A marcou como visto';
  begin
    perform vincular_usuario('gestor.a@teste', 'X', 'secretaria', null);
    assert false, 'gestor não pode se promover';
  exception when insufficient_privilege then null;
  end;
end $$;

\echo '--- sem perfil e sem login'
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-00000000000d', false);
do $$
begin
  assert (select count(*) from solicitacoes) = 0, 'usuário sem perfil não vê nada';
  begin
    insert into solicitacoes (categoria, item, quantidade) values ('tecnologia', 'X', 1);
    assert false, 'sem perfil não cadastra';
  exception when raise_exception then null;
  end;
end $$;
reset role;
set role anon;
select set_config('request.jwt.claim.sub', '', false);
do $$
begin
  assert (select count(*) from solicitacoes) = 0, 'anônimo não vê nada';
  assert (select count(*) from perfis) = 0, 'anônimo não vê perfis';
end $$;
reset role;
\echo 'TODOS OS TESTES PASSARAM'
