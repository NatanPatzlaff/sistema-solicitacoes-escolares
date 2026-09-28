# Memória do projeto

> Registrar apenas o que ajuda na continuidade. Datas no formato AAAA-MM-DD.

## Decisões aprovadas

- 2026-09-24 — Estrutura documental: CLAUDE.md, specs/sistema.md, specs/design.md, memoria.md.
- 2026-09-24 — Sem identidade visual oficial. Identidade própria: base clean com detalhes em dourado, amarelo e vermelho (ver specs/design.md).
- 2026-09-24 — **Custo zero é requisito.** Nenhum serviço pago, nem domínio próprio.
- 2026-09-24 — Stack: React + Vite + TypeScript (estático) · Supabase gratuito (Postgres, Auth, RLS) · Cloudflare Pages · GitHub privado.
- 2026-09-24 — Anti-pausa do Supabase: consulta diária via GitHub Actions. Backup semanal (`pg_dump`) via GitHub Actions, como artefato privado.
- 2026-09-24 — Repositório **privado**: backup não pode ser público, e em repositório público o GitHub desativa tarefas agendadas após 60 dias sem commits.
- 2026-09-24 — Escala: 5 unidades escolares; lançamentos manuais e esporádicos (por isso o risco real de 7 dias sem uso).

## Decisões provisórias (a confirmar)

Já implementadas assim na primeira versão (2026-09-28); mudar é simples se forem recusadas:
- Autenticação: e-mail e senha. Contas criadas no painel do Supabase e vinculadas por `vincular_usuario()` no SQL Editor (sem tela de gestão de contas).
- Notificação: aviso dentro do sistema (contador no menu + linha destacada), some quando o gestor abre a solicitação.
- Quem marca "Entregue": a Secretaria.
- Gestor não edita nem cancela solicitações.
- Justificativa obrigatória em "Indisponível" e "Não atendida"; quantidade adquirida obrigatória em "Adquirida".
- Escopo da primeira versão conforme §11 de specs/sistema.md.

## Decisões rejeitadas

- 2026-09-24 — Next.js: desnecessário (o isolamento é feito por RLS no banco, sem servidor próprio); mais coisas para manter.
- 2026-09-24 — Vercel: o plano Hobby gratuito é restrito a uso não comercial; sistema de prefeitura fica em zona cinzenta.
- 2026-09-24 — Cloudflare Workers Cron para anti-pausa: funciona, mas não resolve o backup; o GitHub Actions resolve os dois.

## Alterações realizadas

- 2026-09-24 — Criação dos quatro arquivos de documentação.
- 2026-09-24 — Stack definida; repositório privado criado no GitHub com a base do projeto (Vite + React + TS).
- 2026-09-28 — Primeira versão do site: login/recuperação de senha, lista única para gestor e Secretaria (cards de status, filtros, busca sem acento, paginação 25), cadastro (gestor), detalhe com histórico e atendimento (Secretaria). Rotas por hash.
- 2026-09-28 — Banco em `supabase/schema.sql`: RLS por unidade + triggers que forçam unidade do gestor, travam campos do pedido e aplicam o ciclo de status. Testes em `supabase/teste.sql`.

## Problemas encontrados

- Plano gratuito do Supabase pausa o projeto após 7 dias sem uso e não oferece backup baixável.
- 2026-09-28 — Função `vincular_usuario`: parâmetro `nome` conflitava com a coluna `nome` (ambiguidade PL/pgSQL). Pego pelo teste.
- 2026-09-28 — Falha de rede ao carregar o perfil aparecia como "Conta sem perfil".

## Soluções aplicadas

- Consulta diária + backup semanal via GitHub Actions (a implementar quando o projeto Supabase existir).
- `#variable_conflict use_column` + parâmetros qualificados em `vincular_usuario`.
- Tela própria de erro de conexão com "Tentar de novo".
- Testes do banco rodam num PostgreSQL 17 portátil (em `%LOCALAPPDATA%\pgsql-portable`, sem instalação/serviço), recriado do zero a cada execução.

## Riscos conhecidos

- A consulta diária contorna a pausa; o Supabase pode mudar essa política. O backup semanal garante que nenhum dado se perca.

## Pendências

- Confirmar método de autenticação.
- Nº de gestores por unidade e de usuários da Secretaria.
- Formato das notificações.
- Exemplos da categoria Manutenção e infraestrutura.
- Gestor pode editar/cancelar solicitação em "Cadastrada"?
- Quem confirma "Entregue"?
- Justificativa obrigatória em "Indisponível" / "Não atendida"?
- Prazo e prioridades da primeira entrega.

## Próximos passos

1. Criar o projeto no Supabase (gratuito), rodar `supabase/schema.sql` e criar as contas (passo a passo no README.md).
2. Criar os workflows de anti-pausa e backup (precisam das chaves do Supabase).
3. Conectar o repositório ao Cloudflare Pages.
4. Testar o fluxo completo com dados reais e responder às pendências.
