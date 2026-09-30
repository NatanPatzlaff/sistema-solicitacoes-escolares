-- Sistema de Solicitações das Unidades Escolares — banco de dados.
-- Rodar uma vez no SQL Editor do Supabase (projeto novo).
-- Regras de negócio: specs/sistema.md. O banco é a última barreira:
-- isolamento por unidade e ciclo de status valem mesmo para chamadas diretas à API.
--
-- Modelo: uma solicitação (o pedido da escola) tem um ou mais itens.
-- O status é de cada item; a solicitação só resume os itens.

create extension if not exists unaccent with schema extensions;

create type papel as enum ('gestor', 'secretaria');
create type categoria as enum (
  'limpeza_higiene',
  'material_expediente',
  'material_escolar_pedagogico',
  'tecnologia',
  'manutencao_infraestrutura',
  'cozinha_utensilios',
  'mobiliario_equipamentos'
);
create type status_item as enum (
  'cadastrada', 'em_analise', 'adquirida', 'indisponivel', 'nao_atendida', 'entregue'
);

create table unidades (
  id bigint generated always as identity primary key,
  nome text not null unique
);

create table perfis (
  id uuid primary key references auth.users on delete cascade,
  nome text not null,
  email text not null,
  papel papel not null,
  unidade_id bigint references unidades,
  -- gestor tem exatamente uma unidade; Secretaria não tem nenhuma
  check ((papel = 'gestor') = (unidade_id is not null))
);

create table solicitacoes (
  id bigint generated always as identity primary key,
  unidade_id bigint not null references unidades,
  observacoes text,
  criado_por uuid references perfis,
  criado_em timestamptz not null default now()
);
create index on solicitacoes (unidade_id, criado_em desc);
create index on solicitacoes (criado_em desc);

create table itens (
  id bigint generated always as identity primary key,
  solicitacao_id bigint not null references solicitacoes on delete cascade,
  -- cópia da unidade da solicitação (preenchida pelo banco) para o RLS não precisar de join
  unidade_id bigint not null references unidades,
  categoria categoria not null,
  item text not null check (length(trim(item)) between 1 and 200),
  item_busca text not null default '',
  quantidade int not null check (quantidade > 0),
  observacoes text,
  status status_item not null default 'cadastrada',
  justificativa text,
  quantidade_adquirida int check (quantidade_adquirida >= 0),
  previsao_entrega date,
  criado_em timestamptz not null default now(),
  atualizado_em timestamptz not null default now()
);
create index on itens (solicitacao_id);
create index on itens (unidade_id);

-- Cada mudança de status de um item: quem e quando (visível aos dois perfis).
create table historico (
  id bigint generated always as identity primary key,
  item_id bigint not null references itens on delete cascade,
  status status_item not null,
  alterado_por uuid references perfis,
  alterado_por_nome text not null,
  alterado_em timestamptz not null default now()
);
create index on historico (item_id);

-- Aviso ao gestor: o status do item mudou e ele ainda não abriu a solicitação.
create table novidades (
  item_id bigint primary key references itens on delete cascade
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

-- ---------------------------------------------------------------- Regras (triggers)

-- Solicitação: a unidade vem do vínculo do gestor, nunca do formulário.
create function antes_de_criar_solicitacao() returns trigger
language plpgsql set search_path = public
as $$
begin
  if via_api() then
    if meu_papel() is distinct from 'gestor' then
      raise exception 'Apenas gestores cadastram solicitações.';
    end if;
    new.unidade_id := minha_unidade();
    new.criado_por := auth.uid();
    new.criado_em := now();
  end if;
  new.observacoes := nullif(trim(new.observacoes), '');
  return new;
end $$;

create trigger antes_de_criar_solicitacao before insert on solicitacoes
for each row execute function antes_de_criar_solicitacao();

-- Item novo: herda a unidade da solicitação e sempre começa como "cadastrada".
create function antes_de_cadastrar_item() returns trigger
language plpgsql set search_path = public
as $$
begin
  new.unidade_id := (select unidade_id from solicitacoes where id = new.solicitacao_id);
  if via_api() then
    if meu_papel() is distinct from 'gestor' then
      raise exception 'Apenas gestores cadastram itens.';
    end if;
    if new.unidade_id is distinct from minha_unidade() then
      raise exception 'Solicitação de outra unidade.';
    end if;
  end if;
  new.status := 'cadastrada';
  new.justificativa := null;
  new.quantidade_adquirida := null;
  new.previsao_entrega := null;
  new.item := trim(new.item);
  new.item_busca := lower(extensions.unaccent(new.item));
  new.observacoes := nullif(trim(new.observacoes), '');
  new.criado_em := now();
  new.atualizado_em := now();
  return new;
end $$;

create trigger antes_de_cadastrar_item before insert on itens
for each row execute function antes_de_cadastrar_item();

-- Atualização: Secretaria atende; gestor só confirma o recebimento (§5).
create function antes_de_atualizar_item() returns trigger
language plpgsql set search_path = public
as $$
begin
  -- dados do pedido não mudam depois de cadastrados
  new.solicitacao_id := old.solicitacao_id;
  new.unidade_id := old.unidade_id;
  new.categoria := old.categoria;
  new.item := old.item;
  new.item_busca := old.item_busca;
  new.quantidade := old.quantidade;
  new.observacoes := old.observacoes;
  new.criado_em := old.criado_em;
  new.justificativa := nullif(trim(new.justificativa), '');

  if via_api() then
    case meu_papel()
      when 'gestor' then
        if not (old.status = 'adquirida' and new.status = 'entregue') then
          raise exception 'A escola só pode confirmar o recebimento de itens adquiridos.';
        end if;
        new.justificativa := old.justificativa;
        new.quantidade_adquirida := old.quantidade_adquirida;
        new.previsao_entrega := old.previsao_entrega;
      when 'secretaria' then
        if new.status = 'entregue' and old.status <> 'entregue' then
          raise exception 'Quem confirma a entrega é a escola.';
        end if;
      else
        raise exception 'Sem permissão para alterar itens.';
    end case;
  end if;

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
  if new.status in ('indisponivel', 'nao_atendida') and new.justificativa is null then
    raise exception 'Informe a justificativa.';
  end if;
  if new.quantidade_adquirida is distinct from old.quantidade_adquirida
     and new.quantidade_adquirida <> new.quantidade and new.justificativa is null then
    raise exception 'Quantidade adquirida diferente da pedida: informe a justificativa.';
  end if;

  new.atualizado_em := now();
  return new;
end $$;

create trigger antes_de_atualizar_item before update on itens
for each row execute function antes_de_atualizar_item();

create function registrar_historico() returns trigger
language plpgsql security definer set search_path = public
as $$
begin
  if tg_op = 'INSERT' or new.status <> old.status then
    insert into historico (item_id, status, alterado_por, alterado_por_nome)
    values (new.id, new.status, auth.uid(),
            coalesce((select nome from perfis where id = auth.uid()), 'Sistema'));
  end if;
  -- aviso para a escola só quando quem mudou foi a Secretaria
  if tg_op = 'UPDATE' and new.status <> old.status and meu_papel() is distinct from 'gestor' then
    insert into novidades values (new.id) on conflict do nothing;
  end if;
  return null;
end $$;

create trigger registrar_historico after insert or update on itens
for each row execute function registrar_historico();

-- ---------------------------------------------------------------- Operações do site

-- Gestor: cria a solicitação com todos os itens de uma vez (tudo ou nada).
-- p_itens: [{"categoria": "...", "item": "...", "quantidade": 3, "observacoes": "..."}, ...]
create function criar_solicitacao(p_observacoes text, p_itens jsonb) returns bigint
language plpgsql set search_path = public
as $$
declare sid bigint;
begin
  if jsonb_typeof(p_itens) is distinct from 'array' or jsonb_array_length(p_itens) = 0 then
    raise exception 'Inclua pelo menos um item.';
  end if;
  insert into solicitacoes (observacoes) values (p_observacoes) returning id into sid;
  insert into itens (solicitacao_id, categoria, item, quantidade, observacoes)
  select sid, (x ->> 'categoria')::categoria, x ->> 'item', (x ->> 'quantidade')::int, x ->> 'observacoes'
  from jsonb_array_elements(p_itens) x;
  return sid;
end $$;

-- Secretaria: atualiza um ou vários itens de uma vez (tudo ou nada).
-- Parâmetros nulos mantêm o valor atual. Ao marcar "adquirida" sem quantidade,
-- cada item recebe a quantidade que foi pedida.
create function atualizar_itens(
  p_ids bigint[],
  p_status status_item default null,
  p_quantidade_adquirida int default null,
  p_justificativa text default null,
  p_previsao_entrega date default null
) returns int
language plpgsql set search_path = public
as $$
declare
  r itens;
  n int;
  total int := 0;
  novo status_item;
begin
  for r in select * from itens where id = any(p_ids) order by id loop
    novo := coalesce(p_status, r.status);
    begin
      update itens set
        status = novo,
        quantidade_adquirida = coalesce(p_quantidade_adquirida, r.quantidade_adquirida,
          case when novo in ('adquirida', 'entregue') then r.quantidade end),
        justificativa = coalesce(nullif(trim(p_justificativa), ''), r.justificativa),
        previsao_entrega = coalesce(p_previsao_entrega, r.previsao_entrega)
      where id = r.id;
      get diagnostics n = row_count;
      if n = 0 then
        raise exception 'Sem permissão para alterar.';
      end if;
    exception when others then
      raise exception 'Item "%": %', r.item, sqlerrm;
    end;
    total := total + 1;
  end loop;
  if total <> (select count(distinct x) from unnest(p_ids) x) then
    raise exception 'Algum item não foi encontrado.';
  end if;
  return total;
end $$;

-- Lista de solicitações com resumo dos itens (respeita o RLS de quem chama).
-- Filtros de item mostram as solicitações que têm algum item assim.
create function buscar_solicitacoes(
  p_escola bigint default null,
  p_categoria categoria default null,
  p_status status_item default null,
  p_de timestamptz default null,
  p_ate timestamptz default null,
  p_item text default null,
  p_limite int default 25,
  p_deslocamento int default 0
) returns table (
  id bigint, escola text, observacoes text, criado_em timestamptz,
  total_itens int, por_status jsonb, novidade boolean, total bigint
)
language sql stable set search_path = public
as $$
  with filtradas as (
    select s.* from solicitacoes s
    where (p_escola is null or s.unidade_id = p_escola)
      and (p_de is null or s.criado_em >= p_de)
      and (p_ate is null or s.criado_em < p_ate)
      and (
        (p_categoria is null and p_status is null and coalesce(trim(p_item), '') = '')
        or exists (
          select 1 from itens i
          where i.solicitacao_id = s.id
            and (p_categoria is null or i.categoria = p_categoria)
            and (p_status is null or i.status = p_status)
            and (coalesce(trim(p_item), '') = ''
                 or strpos(i.item_busca, lower(extensions.unaccent(trim(p_item)))) > 0)
        )
      )
  )
  select
    f.id, u.nome, f.observacoes, f.criado_em,
    (select count(*)::int from itens i where i.solicitacao_id = f.id),
    (select coalesce(jsonb_object_agg(x.status, x.n), '{}') from (
       select i.status::text as status, count(*) as n from itens i
       where i.solicitacao_id = f.id group by i.status) x),
    exists (select 1 from novidades nv join itens i on i.id = nv.item_id where i.solicitacao_id = f.id),
    count(*) over ()
  from filtradas f
  join unidades u on u.id = f.unidade_id
  order by f.criado_em desc, f.id desc
  limit p_limite offset p_deslocamento
$$;

-- Contagem de itens por status para os cards do painel.
create function contagem_por_status()
returns table (status status_item, total int)
language sql stable
as $$ select status, count(*)::int from itens group by status $$;

-- ---------------------------------------------------------------- RLS
alter table unidades enable row level security;
alter table perfis enable row level security;
alter table solicitacoes enable row level security;
alter table itens enable row level security;
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

create policy ver on itens for select to authenticated
using ((select meu_papel()) = 'secretaria' or unidade_id = (select minha_unidade()));

create policy cadastrar on itens for insert to authenticated
with check ((select meu_papel()) = 'gestor' and unidade_id = (select minha_unidade()));

-- Secretaria atende qualquer item; gestor só mexe em itens adquiridos da própria escola
-- (o trigger limita a mudança a "entregue").
create policy atualizar on itens for update to authenticated
using ((select meu_papel()) = 'secretaria'
       or (unidade_id = (select minha_unidade()) and status = 'adquirida'))
with check ((select meu_papel()) = 'secretaria' or unidade_id = (select minha_unidade()));

create policy ver on historico for select to authenticated
using (item_id in (select id from itens));

create policy ver on novidades for select to authenticated
using (item_id in (select id from itens where unidade_id = (select minha_unidade())));

create policy marcar_vista on novidades for delete to authenticated
using (item_id in (select id from itens where unidade_id = (select minha_unidade())));

-- ---------------------------------------------------------------- Contas
-- No dia a dia, a Secretaria cria contas pela tela "Contas" (Edge Function criar-conta).
-- Esta função serve para a PRIMEIRA conta da Secretaria (SQL Editor, depois de criar
-- o usuário em Authentication > Users):
--   select vincular_usuario('compras@educacao.gov', 'João Lima', 'secretaria', null);
-- Também aceita gestor: vincular_usuario('diretora@escola.com', 'Maria Souza', 'gestor', 'EMEF Centro').
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
  insert into perfis (id, nome, email, papel, unidade_id)
  values (uid, vincular_usuario.nome, vincular_usuario.email, vincular_usuario.papel, uni)
  on conflict (id) do update
    set nome = excluded.nome, email = excluded.email, papel = excluded.papel, unidade_id = excluded.unidade_id;
end $$;

revoke execute on function vincular_usuario from public, anon, authenticated;
revoke execute on function via_api from public, anon;
