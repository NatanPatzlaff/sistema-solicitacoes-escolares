# Sistema de Solicitações das Unidades Escolares

Sistema on-line da Secretaria Municipal de Educação para registrar, acompanhar e atender solicitações de materiais, equipamentos e manutenção/infraestrutura das unidades escolares. Dois perfis: **Gestor da unidade** e **Secretaria**.

**Custo zero:** o projeto não pode gerar nenhum gasto. Stack: React + Vite + TypeScript · Supabase (gratuito) · Cloudflare Pages · GitHub privado (detalhes em @specs/sistema.md §9). Nunca sugira serviço, plano ou dependência paga.

## Fontes de verdade

- O que construir: @specs/sistema.md
- Como deve parecer: @specs/design.md
- Histórico de decisões, pendências e próximos passos: @memoria.md

Leia os três antes de qualquer tarefa relevante.

## Regra obrigatória

Se algum pedido meu contradisser uma decisão registrada em @specs/sistema.md, @specs/design.md ou @memoria.md, pare e me avise antes de realizar qualquer alteração. Explique qual decisão seria afetada e pergunte se desejo substituí-la.

## Regras de trabalho

- Não altere a stack técnica sem minha autorização.
- Não remova uma decisão aprovada silenciosamente.
- Não invente categorias, status, permissões ou regras de fluxo que não estejam especificadas em @specs/sistema.md.
- Nunca misture os dados de uma unidade escolar com os de outra — todo gestor só pode ver solicitações da própria unidade.
- Sempre preserve a consistência entre as telas do gestor e as da Secretaria (mesmos status, mesmas categorias, mesma nomenclatura).
- Antes de uma mudança grande, apresente um plano resumido.
- Depois de uma decisão importante aprovada, atualize @memoria.md.

## Instruções essenciais

- Idioma da interface, do código de domínio e da documentação: português do Brasil.
- Itens marcados como **a confirmar** nas specs são provisórios: pergunte antes de construir algo que dependa deles.
- Prefira a solução mais simples que atenda à spec; nada de funcionalidade "para o futuro".
