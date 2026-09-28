# Sistema de Solicitações das Unidades Escolares

Documentação do projeto: [CLAUDE.md](CLAUDE.md), [specs/sistema.md](specs/sistema.md), [specs/design.md](specs/design.md), [memoria.md](memoria.md).

## Colocar no ar (custo zero)

1. **Supabase** (supabase.com, plano gratuito): crie um projeto e, no **SQL Editor**, rode todo o conteúdo de [supabase/schema.sql](supabase/schema.sql).
2. **Contas:** em *Authentication > Users > Add user*, crie cada usuário (e-mail + senha). Depois, no SQL Editor, vincule:
   ```sql
   select vincular_usuario('diretora@escola.com', 'Maria Souza', 'gestor', 'EMEF Centro');
   select vincular_usuario('compras@educacao.gov.br', 'João Lima', 'secretaria', null);
   ```
   A escola é criada automaticamente na primeira vez em que aparece.
3. **Recuperação de senha:** em *Authentication > URL Configuration*, coloque o endereço do site em *Site URL*.
4. **Chaves:** copie `.env.example` para `.env.local` e preencha com *Project URL* e *anon public key* (Project Settings > API).
5. **Cloudflare Pages:** conecte este repositório; comando de build `npm run build`, pasta `dist`; adicione as duas variáveis `VITE_SUPABASE_*`.

## Desenvolvimento

```sh
npm install
npm run dev
```

O arquivo [supabase/teste.sql](supabase/teste.sql) testa isolamento por unidade, permissões e ciclo de status num PostgreSQL local vazio (não rodar no Supabase).
