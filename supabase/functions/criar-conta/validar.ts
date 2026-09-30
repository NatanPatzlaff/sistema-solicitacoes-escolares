// Validação do pedido de nova conta (testada em validar.test.ts).
export type Pedido = {
  nome: string
  email: string
  senha: string
  papel: 'gestor' | 'secretaria'
  unidade_id: number | null
  nova_unidade: string | null
}

// deno-lint-ignore no-explicit-any
export function validar(b: any): string | Pedido {
  const nome = String(b?.nome ?? '').trim()
  const email = String(b?.email ?? '').trim().toLowerCase()
  const senha = String(b?.senha ?? '')
  const papel = b?.papel
  if (!nome) return 'Informe o nome.'
  if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) return 'E-mail inválido.'
  if (senha.length < 8) return 'A senha provisória precisa ter pelo menos 8 caracteres.'
  if (papel !== 'gestor' && papel !== 'secretaria') return 'Perfil inválido.'
  if (papel === 'secretaria') return { nome, email, senha, papel, unidade_id: null, nova_unidade: null }
  const nova_unidade = String(b?.nova_unidade ?? '').trim() || null
  const unidade_id = nova_unidade ? null : Number(b?.unidade_id) || null
  if (!unidade_id && !nova_unidade) return 'Escolha a escola do gestor.'
  return { nome, email, senha, papel, unidade_id, nova_unidade }
}
