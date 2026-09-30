import { CATEGORIAS, STATUS, type Categoria, type Status } from './dominio'

const ICONES: Record<Status, string> = {
  cadastrada: 'M8 2a6 6 0 1 0 0 12A6 6 0 0 0 8 2z',
  em_analise: 'M8 2a6 6 0 1 0 0 12A6 6 0 0 0 8 2zM8 5v3.2l2.2 1.4',
  adquirida: 'M2.5 5 8 2.5 13.5 5v6L8 13.5 2.5 11zM2.5 5 8 7.5 13.5 5M8 7.5v6',
  entregue: 'M3 8.5l3.2 3.2L13 5',
  indisponivel: 'M8 2a6 6 0 1 0 0 12A6 6 0 0 0 8 2zM3.8 12.2l8.4-8.4',
  nao_atendida: 'M4.5 4.5l7 7M11.5 4.5l-7 7',
}

export function IconeStatus({ status }: { status: Status }) {
  return (
    <svg width="14" height="14" viewBox="0 0 16 16" aria-hidden="true" fill="none"
      stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round">
      <path d={ICONES[status]} />
    </svg>
  )
}

export function BadgeStatus({ status }: { status: Status }) {
  return (
    <span className={`badge status-${status}`}>
      <IconeStatus status={status} />
      {STATUS[status]}
    </span>
  )
}

// Resumo dos itens de uma solicitação: ícone + número por status (nome no leitor de tela e no tooltip).
export function ResumoItens({ porStatus }: { porStatus: Partial<Record<Status, number>> }) {
  return (
    <span className="resumo">
      {(Object.keys(STATUS) as Status[]).filter((s) => porStatus[s]).map((s) => (
        <span key={s} className={`badge status-${s}`} title={STATUS[s]}>
          <IconeStatus status={s} />
          {porStatus[s]}
          <span className="sr"> {STATUS[s]}</span>
        </span>
      ))}
    </span>
  )
}

export function BadgeCategoria({ categoria }: { categoria: Categoria }) {
  return <span className="badge categoria">{CATEGORIAS[categoria]}</span>
}

export function Erro({ children }: { children: string }) {
  return children ? <p className="erro" role="alert">{children}</p> : null
}
