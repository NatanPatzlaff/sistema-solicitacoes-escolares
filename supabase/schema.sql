-- Sistema de Solicitações das Unidades Escolares — banco de dados.
-- Rodar uma vez no SQL Editor do Supabase (projeto novo).
-- Regras de negócio: specs/sistema.md. O banco é a última barreira:
-- isolamento por unidade e ciclo de status valem mesmo para chamadas diretas à API.

create extension if not exists unaccent with schema extensions;

create type papel as enum ('gestor', 'secretaria');
create type categoria as enum (
  'limpeza_higiene',
  'material_expediente',
  'material_escolar_pedagogico',
  'tecnologia',
  'manutencao_infraestrutura'
);
create type status_solicitacao as enum (
  'cadastrada', 'em_analise', 'adquirida', 'indisponivel', 'nao_atendida', 'entregue'
);

create table unidades (
  id bigint generated always as identity primary key,
  nome text not null unique
);

create table perfis (
  id uuid primary key references auth.users on delete cascade,
  nome text not null,
  papel papel not null,
  unidade_id bigint references unidades,
  -- gestor tem exatamente uma unidade; Secretaria não tem nenhuma
  check ((papel = 'gestor') = (unidade_id is not null))
);

create table solicitacoes (
  id bigint generated always as identity primary key,
  unidade_id bigint not null references unidades,
  categoria categoria not null,
  item text not null check (length(trim(item)) between 1 and 200),
  item_busca text not null default '',
  quantidade int not null check (quantidade > 0),
  observacoes text,
  status status_solicitacao not null default 'cadastrada',
  justificativa text,
  quantidade_adquirida int check (quantidade_adquirida >= 0),
  previsao_entrega date,
  criado_por uuid references perfis,
  criado_em timestamptz not null default now(),
  atualizado_em timestamptz not null default now()
);
create index on solicitacoes (unidade_id, criado_em desc);
create index on solicitacoes (criado_em desc);

-- Cada mudança de status: quem e quando (visível aos dois perfis).
create table historico (
  id bigint generated always as identity primary key,
  solicitacao_id bigint not null references solicitacoes on delete cascade,
  status status_solicitacao not null,
  alterado_por uuid references perfis,
  alterado_por_nome text not null,
  alterado_em timestamptz not null default now()
);
create index on historico (solicitacao_id);

-- Aviso ao gestor: status mudou e ele ainda não abriu a solicitação.
create table novidades (
  solicitacao_id bigint primary key references solicitacoes on delete cascade
);

-- Funções de apoio (security definer evita recursão nas políticas de perfis).
create function meu_papel() returns papel
language sql stable security definer set search_path = public
as $$ select papel from perfis where id = auth.uid() $$;

create function minha_unidade() returns bigint
language sql stable security definer set search_path = public
as $$ select unidade_id from perfis where id = auth.uid() $$;

-- Chamadas vindas do site (anon/authenticated) seguem as regras;
-- o SQL Editor (postgres) pode corrigir dados manualmente.
create function via_api() returns boolean
language sql stable
as $$ select current_user in ('anon', 'authenticated') $$;

-- Cadastro: a unidade vem do vínculo do gestor, nunca do formulário.
create function antes_de_cadastrar() returns trigger
language plpgsql set search_path = public
as $$
begin
  if via_api() then
    if meu_papel() is distinct from 'gestor' then
      raise exception 'Apenas gestores cadastram solicitações.';
    end if;
    new.unidade_id := minha_unidade();
    new.criado_por := auth.uid();
  end if;
  new.status := 'cadastrada';
  new.justificativa := null;
  new.quantidade_adquirida := null;
  new.previsao_entrega := null;
  new.item := trim(new.item);
  new.item_busca := lower(extensions.unaccent(new.item));
  new.criado_em := now();
  new.atualizado_em := now();
  return new;
end $$;

create trigger antes_de_cadastrar before insert on solicitacoes
for each row execute function antes_de_cadastrar();

-- Atualização: só a Secretaria, só os campos dela, só transições do ciclo (§5).
create function antes_de_atualizar() returns trigger
language plpgsql set search_path = public
as $$
begin
  if via_api() and meu_papel() is distinct from 'secretaria' then
    raise exception 'Apenas a Secretaria altera solicitações.';
  end if;

  -- dados do pedido não mudam depois de cadastrados
  new.unidade_id := old.unidade_id;
  new.categoria := old.categoria;
  new.item := old.item;
  new.item_busca := old.item_busca;
  new.quantidade := old.quantidade;
  new.observacoes := old.observacoes;
  new.criado_por := old.criado_por;
  new.criado_em := old.criado_em;

  if new.status <> old.status and not (
       (old.status = 'cadastrada' and new.status = 'em_analise')
    or (old.status = 'em_analise' and new.status in ('adquirida', 'indisponivel', 'nao_atendida'))
    or (old.status = 'adquirida' and new.status = 'entregue')
  ) then
    raise exception 'Mudança de status não permitida.';
  end if;

  if new.status in ('adquirida', 'entregue') and new.quantidade_adquirida is null then
    raise exception 'Informe a quantidade adquirida.';
  end if;
  if new.status in ('indisponivel', 'nao_atendida') and coalesce(trim(new.justificativa), '') = '' then
    raise exception 'Informe a justificativa.';
  end if;

  new.atualizado_em := now();
  return new;
end $$;

create trigger antes_de_atualizar before update on solicitacoes
for each row execute function antes_de_atualizar();

create function registrar_historico() returns trigger
language plpgsql security definer set search_path = public
as $$
begin
  if tg_op = 'INSERT' or new.status <> old.status then
    insert into historico (solicitacao_id, status, alterado_por, alterado_por_nome)
    values (new.id, new.status, auth.uid(),
            coalesce((select nome from perfis where id = auth.uid()), 'Sistema'));
  end if;
  if tg_op = 'UPDATE' and new.status <> old.status then
    insert into novidades values (new.id) on conflict do nothing;
  end if;
  return null;
end $$;

create trigger registrar_historico after insert or update on solicitacoes
for each row execute function registrar_historico();

-- Contagem por status para os cards do painel (respeita o RLS de quem chama).
create function contagem_por_status()
returns table (status status_solicitacao, total int)
language sql stable
as $$ select status, count(*)::int from solicitacoes group by status $$;

-- ---------------------------------------------------------------- RLS
alter table unidades enable row level security;
alter table perfis enable row level security;
alter table solicitacoes enable row level security;
alter table historico enable row level security;
alter table novidades enable row level security;

create policy ver on unidades for select to authenticated
using ((select meu_papel()) = 'secretaria' or id = (select minha_unidade()));

create policy ver on perfis for select to authenticated
using (id = auth.uid() or (select meu_papel()) = 'secretaria');

create policy ver on solicitacoes for select to authenticated
using ((select meu_papel()) = 'secretaria' or unidade_id = (select minha_unidade()));

create policy cadastrar on solicitacoes for insert to authenticated
with check ((select meu_papel()) = 'gestor' and unidade_id = (select minha_unidade()));

create policy atualizar on solicitacoes for update to authenticated
using ((select meu_papel()) = 'secretaria')
with check ((select meu_papel()) = 'secretaria');

create policy ver on historico for select to authenticated
using (solicitacao_id in (select id from solicitacoes));

create policy ver on novidades for select to authenticated
using (solicitacao_id in (select id from solicitacoes where unidade_id = (select minha_unidade())));

create policy marcar_vista on novidades for delete to authenticated
using (solicitacao_id in (select id from solicitacoes where unidade_id = (select minha_unidade())));

-- ---------------------------------------------------------------- Contas
-- Uso (SQL Editor, depois de criar o usuário em Authentication > Users):
--   select vincular_usuario('diretora@escola.com', 'Maria Souza', 'gestor', 'EMEF Centro');
--   select vincular_usuario('compras@educacao.gov', 'João Lima', 'secretaria', null);
-- A unidade é criada se ainda não existir.
create function vincular_usuario(email text, nome text, papel papel, unidade text)
returns void
language plpgsql security definer set search_path = public
as $$
#variable_conflict use_column
declare
  uid uuid := (select id from auth.users u where u.email = vincular_usuario.email);
  uni bigint;
begin
  if uid is null then
    raise exception 'Usuário % não encontrado em Authentication > Users.', vincular_usuario.email;
  end if;
  if vincular_usuario.unidade is not null then
    insert into unidades (nome) values (vincular_usuario.unidade) on conflict (nome) do nothing;
    uni := (select id from unidades u where u.nome = vincular_usuario.unidade);
  end if;
  insert into perfis (id, nome, papel, unidade_id)
  values (uid, vincular_usuario.nome, vincular_usuario.papel, uni)
  on conflict (id) do update
    set nome = excluded.nome, papel = excluded.papel, unidade_id = excluded.unidade_id;
end $$;

revoke execute on function vincular_usuario from public, anon, authenticated;
revoke execute on function via_api from public, anon;
