# Sistema de Solicitações das Unidades Escolares

Documentação do projeto: [CLAUDE.md](CLAUDE.md), [specs/sistema.md](specs/sistema.md), [specs/design.md](specs/design.md), [memoria.md](memoria.md).

## Colocar no ar (custo zero)

1. **Supabase** (supabase.com, plano gratuito): crie um projeto e, no **SQL Editor**, rode nesta ordem:
   [supabase/schema.sql](supabase/schema.sql), os arquivos de [supabase/migracoes/](supabase/migracoes/) (em ordem numérica) e [supabase/catalogo.sql](supabase/catalogo.sql) (catálogo inicial de produtos).
   Mudanças futuras no banco entram como novos arquivos em `migracoes/`, aplicados no projeto que já está no ar.
2. **Fechar o cadastro público:** em *Authentication > Sign In / Providers*, desligue *Allow new users to sign up*. Só a Secretaria cria contas.
3. **Função de criar contas:** publique a Edge Function (gratuita):
   ```sh
   npx supabase login
   npx supabase functions deploy criar-conta --project-ref <id-do-projeto>
   ```
4. **Primeira conta da Secretaria:** em *Authentication > Users > Add user*, crie o usuário (marque *Auto Confirm User*). Depois, no SQL Editor:
   ```sql
   select vincular_usuario('compras@educacao.gov.br', 'João Lima', 'secretaria', null);
   ```
   As demais contas (gestores e Secretaria) são criadas pela tela **Contas** do próprio sistema.
5. **Recuperação de senha:** em *Authentication > URL Configuration*, coloque o endereço do site em *Site URL*.
6. **Chaves:** copie `.env.example` para `.env.local` e preencha com *Project URL* e *anon public key* (Project Settings > API).
7. **Cloudflare Pages:** conecte este repositório; comando de build `npm run build`, pasta `dist`; variáveis `VITE_SUPABASE_URL`, `VITE_SUPABASE_ANON_KEY` e `NODE_VERSION=22`.
8. **Manutenção automática** (GitHub → Settings → Secrets and variables → Actions → *New repository secret*):
   - `SUPABASE_URL` e `SUPABASE_ANON_KEY` — ativam a consulta diária que impede a pausa ([manter-ativo.yml](.github/workflows/manter-ativo.yml)).
   - `SUPABASE_DB_URL` — ativa o backup semanal ([backup.yml](.github/workflows/backup.yml)). Use a *connection string* do **Session pooler** (Supabase → Connect), com a senha do banco no lugar de `[YOUR-PASSWORD]`.
   - Para testar na hora: aba *Actions* → escolha o workflow → *Run workflow*. Os backups ficam em cada execução, em *Artifacts*.

## Desenvolvimento

```sh
npm install
npm run dev
```

### Testes

- `sh supabase/testar-local.sh` — sobe um PostgreSQL local descartável, roda [supabase/teste.sql](supabase/teste.sql) (isolamento por unidade, permissões, ciclo de status) e carrega/confere os dados de teste.
- `deno test supabase/functions/criar-conta` — validação da função de contas.

### Ambiente de testes com dados reais

[supabase/seed.sql](supabase/seed.sql) transforma as listas reais da Cinderela, EEICM e Grupo Escolar Paulo Freire em 4 solicitações com 270 itens, com status, datas e histórico fictícios. Use num **segundo projeto gratuito do Supabase** (o plano grátis permite 2): rode `schema.sql` e depois `seed.sql` no SQL Editor. O seed se recusa a rodar em banco que já tenha solicitações, então não suja a produção.
