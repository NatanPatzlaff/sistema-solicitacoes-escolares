import { createClient } from '@supabase/supabase-js'

const url = import.meta.env.VITE_SUPABASE_URL as string | undefined
const chave = import.meta.env.VITE_SUPABASE_ANON_KEY as string | undefined

export const configurado = Boolean(url && chave)
export const supabase = createClient(url || 'http://localhost', chave || 'sem-chave')

// Nomenclatura única para as telas do gestor e da Secretaria (specs/sistema.md §4 e §5).
export const CATEGORIAS = {
  limpeza_higiene: 'Limpeza e higiene',
  material_expediente: 'Material de expediente',
  material_escolar_pedagogico: 'Material escolar e pedagógico',
  tecnologia: 'Tecnologia',
  manutencao_infraestrutura: 'Manutenção e infraestrutura',
} as const
export type Categoria = keyof typeof CATEGORIAS

export const STATUS = {
  cadastrada: 'Cadastrada',
  em_analise: 'Em análise',
  adquirida: 'Adquirida',
  entregue: 'Entregue',
  indisponivel: 'Indisponível',
  nao_atendida: 'Não atendida',
} as const
export type Status = keyof typeof STATUS

// Transições permitidas; o banco aplica a mesma regra.
export const PROXIMOS: Record<Status, Status[]> = {
  cadastrada: ['em_analise'],
  em_analise: ['adquirida', 'indisponivel', 'nao_atendida'],
  adquirida: ['entregue'],
  entregue: [],
  indisponivel: [],
  nao_atendida: [],
}

export type Perfil = {
  id: string
  nome: string
  papel: 'gestor' | 'secretaria'
  unidade_id: number | null
  unidades: { nome: string } | null
}

export type Solicitacao = {
  id: number
  unidade_id: number
  categoria: Categoria
  item: string
  quantidade: number
  observacoes: string | null
  status: Status
  justificativa: string | null
  quantidade_adquirida: number | null
  previsao_entrega: string | null
  criado_em: string
  atualizado_em: string
  unidades: { nome: string } | null
}

export const data = (iso: string) => new Date(iso).toLocaleDateString('pt-BR')
export const dataHora = (iso: string) =>
  new Date(iso).toLocaleString('pt-BR', { dateStyle: 'short', timeStyle: 'short' })
// Campo date do banco ("2026-10-01"): sem conversão de fuso.
export const dataSimples = (d: string) => d.split('-').reverse().join('/')

// Mesma normalização que o banco aplica em item_busca.
export const normalizar = (s: string) =>
  s.normalize('NFD').replace(/\p{Diacritic}/gu, '').toLowerCase().trim()

export function mensagemErro(e: { message: string } | null) {
  if (!e) return ''
  if (/row-level security|permission denied/i.test(e.message)) return 'Você não tem permissão para esta ação.'
  if (/Invalid login credentials/i.test(e.message)) return 'E-mail ou senha incorretos.'
  if (/fetch/i.test(e.message)) return 'Sem conexão com o servidor. Verifique a internet e tente de novo.'
  return e.message
}
