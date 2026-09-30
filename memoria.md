# Memória do projeto

> Registrar apenas o que ajuda na continuidade. Datas no formato AAAA-MM-DD.

## Decisões aprovadas

- 2026-09-24 — Estrutura documental: CLAUDE.md, specs/sistema.md, specs/design.md, memoria.md.
- 2026-09-24 — Sem identidade visual oficial. Identidade própria: base clean com detalhes em dourado, amarelo e vermelho (ver specs/design.md).
- 2026-09-24 — **Custo zero é requisito.** Nenhum serviço pago, nem domínio próprio.
- 2026-09-24 — Stack: React + Vite + TypeScript (estático) · Supabase gratuito (Postgres, Auth, RLS) · Cloudflare Pages · GitHub privado.
- 2026-09-24 — Anti-pausa do Supabase: consulta diária via GitHub Actions. Backup semanal (`pg_dump`) via GitHub Actions, como artefato privado.
- 2026-09-24 — Repositório **privado**: backup não pode ser público, e em repositório público o GitHub desativa tarefas agendadas após 60 dias sem commits.
- 2026-09-24 — Escala: lançamentos manuais e esporádicos (por isso o risco real de 7 dias sem uso).
- 2026-09-30 — **Escolas (4):** Grupo Escolar Paulo Freire, Creche Municipal, Pré Escolar Cinderela, Marcolino Pedroso. Cadastradas no banco real. No seed, a lista "EEICM" virou Creche Municipal (o PDF é da "Escola de Educação Infantil e Creche Municipal"). Antes se falava em 5 escolas.
- 2026-09-30 — **Fluxo real:** gestor pede → Secretaria compra manualmente no **SimCatarina** (fora do sistema) → registra o resultado. Pode alterar quantidade ou negar, sempre com justificativa. "Aprovar" = marcar *Adquirida*; não há status novo.
- 2026-09-30 — **Solicitação com vários itens.** Status por item; a solicitação só mostra resumo. A Secretaria atua item a item ou em lote (todos/selecionados), tudo ou nada. Justificativa obrigatória também quando a quantidade comprada ≠ pedida.
- 2026-09-30 — Categorias novas: **Cozinha e utensílios** e **Mobiliário e equipamentos** (7 no total).
- 2026-09-30 — **Quem confirma "Entregue" é o gestor** (recebimento na escola). A Secretaria não marca mais "Entregue"; o gestor não muda nenhum outro campo. A confirmação da escola não gera aviso para ela mesma.
- 2026-09-30 — **Colar lista** no cadastro do gestor (parser em `src/colarLista.ts`, testado com `deno test src/colarLista.test.ts`).
- 2026-09-30 — **Lista de compras** para a Secretaria (itens em análise/cadastrados de todas as escolas, agrupados por nome; soma só sem embalagem anotada; copiar como texto). Exceção aprovada ao "sem relatórios" da primeira versão.
- 2026-09-28 — A Secretaria cria as contas pela tela **Contas** do sistema (pedido do usuário). Implementado com Edge Function `criar-conta` (a service_role nunca vai para o site) e cadastro público desligado. Senha provisória gerada pela tela; a pessoa troca por "Esqueci minha senha".

## Decisões provisórias (a confirmar)

Já implementadas assim na primeira versão (2026-09-28); mudar é simples se forem recusadas:
- Notificação: aviso dentro do sistema (contador no menu + linha destacada), some quando o gestor abre a solicitação.
- Gestor não edita nem cancela solicitações.
- Escopo da primeira versão conforme §11 de specs/sistema.md.

## Decisões rejeitadas

- 2026-09-24 — Next.js: desnecessário (o isolamento é feito por RLS no banco, sem servidor próprio); mais coisas para manter.
- 2026-09-24 — Vercel: o plano Hobby gratuito é restrito a uso não comercial; sistema de prefeitura fica em zona cinzenta.
- 2026-09-24 — Cloudflare Workers Cron para anti-pausa: funciona, mas não resolve o backup; o GitHub Actions resolve os dois.
- 2026-09-28 — Criar contas direto do navegador (cadastro público + vínculo): exigiria deixar o cadastro aberto a qualquer pessoa. Preferida a Edge Function.
- 2026-09-30 — Integração automática com o SimCatarina: não há API pública conhecida; robô que preenche o site seria frágil e arriscado. Substituída pela Lista de compras (copiar e lançar manualmente).
- 2026-09-30 — Campo de unidade/embalagem (caixa, pacote, fardo…): as escolas já escrevem a embalagem no pedido (ex.: "Luva M — caixa"). Fica no texto do item ou nas observações; quantidade continua só número.

## Alterações realizadas

- 2026-09-24 — Criação dos quatro arquivos de documentação.
- 2026-09-24 — Stack definida; repositório privado criado no GitHub com a base do projeto (Vite + React + TS).
- 2026-09-28 — Primeira versão do site: login/recuperação de senha, lista única para gestor e Secretaria (cards de status, filtros, busca sem acento, paginação 25), cadastro (gestor), detalhe com histórico e atendimento (Secretaria). Rotas por hash.
- 2026-09-28 — Banco em `supabase/schema.sql`: RLS por unidade + triggers que forçam unidade do gestor, travam campos do pedido e aplicam o ciclo de status. Testes em `supabase/teste.sql`.
- 2026-09-28 — Tela Contas (Secretaria) + Edge Function `supabase/functions/criar-conta` (validação testada com `deno test`). Coluna `email` em `perfis`.
- 2026-09-30 — Modelo refeito: tabelas `solicitacoes` (pedido) + `itens` (status por item); funções `criar_solicitacao`, `atualizar_itens` (lote, tudo ou nada), `buscar_solicitacoes` (lista com resumo e filtros por item). Telas: lista de solicitações com resumo; detalhe com seleção e painel "Atualizar itens"; cadastro com várias linhas (nova linha repete a categoria anterior).
- 2026-09-30 — Dados de teste `supabase/seed.sql` a partir das listas reais (Cinderela, EEICM, Grupo Escolar Paulo Freire): 270 solicitações, 3 escolas. Script `supabase/testar-local.sh` roda testes + seed + `verificar-seed.sql`. Ambiente de testes = 2º projeto gratuito do Supabase. SQLite descartado: não tem RLS nem é o banco real.

- 2026-09-30 — **Supabase no ar** (projeto `solicitacoes-escolares`, ref `bnyhrrlwouezplvlczhn`, São Paulo, Free): schema aplicado, cadastro público desligado (confirmado: "signup_disabled"), função `criar-conta` publicada, conta **Suporte** (contanatpatz@gmail.com) vinculada como Secretaria. Secrets do GitHub cadastrados; consulta diária e backup rodaram com sucesso (backup de 14 KB).
- 2026-09-30 — **Teste de ponta a ponta no banco real** (navegador + console + rede): criar gestor pela tela Contas, colar lista, lote "Em análise", compra parcial com justificativa, negativa, aviso ao gestor, confirmação de recebimento. Tentativas de burlar pela API (Secretaria marcar entregue, reduzir sem justificativa, mexer em item final; gestor alterar quantidade, criar conta) todas barradas. Nenhum erro no console. Dados de teste no banco real: "Escola Teste", "Gestor Teste" (gestor.teste@exemplo.com), Solicitação nº 1 — apagar antes do uso real.

## Problemas encontrados

- Plano gratuito do Supabase pausa o projeto após 7 dias sem uso e não oferece backup baixável.
- 2026-09-28 — Função `vincular_usuario`: parâmetro `nome` conflitava com a coluna `nome` (ambiguidade PL/pgSQL). Pego pelo teste.
- 2026-09-28 — Falha de rede ao carregar o perfil aparecia como "Conta sem perfil".

## Soluções aplicadas

- Consulta diária + backup semanal via GitHub Actions (a implementar quando o projeto Supabase existir).
- `#variable_conflict use_column` + parâmetros qualificados em `vincular_usuario`.
- Tela própria de erro de conexão com "Tentar de novo".
- Testes do banco rodam num PostgreSQL 17 portátil (em `%LOCALAPPDATA%\pgsql-portable`, sem instalação/serviço), recriado do zero a cada execução: `sh supabase/testar-local.sh`.

## Riscos conhecidos

- A consulta diária contorna a pausa; o Supabase pode mudar essa política. O backup semanal garante que nenhum dado se perca.

## Pendências

Levantadas pelas listas reais das escolas (2026-09-30) — mudam o modelo de dados, decidir antes de ir ao ar:
- Editar/desativar contas pela tela (hoje só pelo painel do Supabase) — avaliar se for preciso.
- Nº de gestores por unidade e de usuários da Secretaria.
- Formato das notificações.
- Exemplos da categoria Manutenção e infraestrutura.
- Gestor pode editar/cancelar solicitação em "Cadastrada"?
- Prazo e prioridades da primeira entrega.

## Próximos passos

1. Publicar o site no Cloudflare Pages e colocar o endereço em Authentication → URL Configuration → Site URL (recuperação de senha).
2. Apagar os dados de teste do banco real (Escola Teste, Gestor Teste, Solicitação nº 1).
3. Criar as contas reais das 5 escolas pela tela Contas.
