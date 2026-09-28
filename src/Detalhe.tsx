import { useEffect, useState, type FormEvent } from 'react'
import {
  PROXIMOS, STATUS, data, dataHora, dataSimples, mensagemErro, supabase,
  type Perfil, type Solicitacao, type Status,
} from './dominio'
import { BadgeCategoria, BadgeStatus, Erro } from './ui'

type Evento = { id: number; status: Status; alterado_por_nome: string; alterado_em: string }

export function Detalhe({ id, perfil }: { id: number; perfil: Perfil }) {
  const [s, setS] = useState<Solicitacao | null | undefined>(undefined)
  const [historico, setHistorico] = useState<Evento[]>([])
  const [erro, setErro] = useState('')

  async function carregar() {
    const [sol, hist] = await Promise.all([
      supabase.from('solicitacoes').select('*, unidades(nome)').eq('id', id).maybeSingle(),
      supabase.from('historico').select('id, status, alterado_por_nome, alterado_em')
        .eq('solicitacao_id', id).order('alterado_em'),
    ])
    setErro(mensagemErro(sol.error ?? hist.error))
    setS(sol.data as Solicitacao | null)
    setHistorico((hist.data ?? []) as Evento[])
  }

  useEffect(() => {
    carregar()
    // Gestor abriu a solicitação: o aviso de atualização some.
    if (perfil.papel === 'gestor') supabase.from('novidades').delete().eq('solicitacao_id', id).then()
  }, [id]) // eslint-disable-line react-hooks/exhaustive-deps

  if (s === undefined) return erro ? <Erro>{erro}</Erro> : null
  if (s === null) {
    return (
      <div className="vazio">
        <p>Solicitação não encontrada.</p>
        <a className="botao secundario" href="#/">Voltar para solicitações</a>
      </div>
    )
  }

  return (
    <>
      <a className="voltar" href="#/" onClick={(e) => { if (history.length > 1) { e.preventDefault(); history.back() } }}>
        ← Solicitações
      </a>
      <div className="cabecalho-pagina">
        <h1>{s.item}</h1>
        <BadgeStatus status={s.status} />
      </div>

      <div className="detalhe">
        <section className="bloco">
          <h2>Pedido</h2>
          <dl className="campos">
            <dt>Escola</dt><dd>{s.unidades?.nome}</dd>
            <dt>Categoria</dt><dd><BadgeCategoria categoria={s.categoria} /></dd>
            <dt>Quantidade</dt><dd className="num-esq">{s.quantidade}</dd>
            <dt>Observações</dt><dd>{s.observacoes || '—'}</dd>
            <dt>Cadastrada em</dt><dd>{data(s.criado_em)}</dd>
          </dl>
        </section>

        <section className="bloco">
          <h2>Atendimento</h2>
          <dl className="campos">
            <dt>Quantidade adquirida</dt><dd className="num-esq">{s.quantidade_adquirida ?? '—'}</dd>
            <dt>Previsão de entrega</dt><dd>{s.previsao_entrega ? dataSimples(s.previsao_entrega) : '—'}</dd>
            <dt>Justificativa</dt><dd>{s.justificativa || '—'}</dd>
          </dl>
          {perfil.papel === 'secretaria' && <Atender key={s.id} s={s} aoSalvar={carregar} />}
        </section>

        <section className="bloco">
          <h2>Histórico</h2>
          <ol className="historico">
            {historico.map((h) => (
              <li key={h.id}>
                <BadgeStatus status={h.status} />
                <span className="suave">{dataHora(h.alterado_em)} · {h.alterado_por_nome}</span>
              </li>
            ))}
          </ol>
        </section>
      </div>
    </>
  )
}

const FINAIS: Status[] = ['entregue', 'indisponivel', 'nao_atendida']

function Atender({ s, aoSalvar }: { s: Solicitacao; aoSalvar: () => void }) {
  const [status, setStatus] = useState<Status>(s.status)
  const [qtd, setQtd] = useState(s.quantidade_adquirida?.toString() ?? '')
  const [previsao, setPrevisao] = useState(s.previsao_entrega ?? '')
  const [justificativa, setJustificativa] = useState(s.justificativa ?? '')
  const [erro, setErro] = useState('')
  const [salvo, setSalvo] = useState('')
  const [enviando, setEnviando] = useState(false)

  if (FINAIS.includes(s.status)) {
    return <p className="suave">Status final. Esta solicitação não pode mais ser alterada.</p>
  }

  const pedeQtd = status === 'adquirida' || status === 'entregue'
  const pedeJustificativa = status === 'indisponivel' || status === 'nao_atendida'

  async function salvar(e: FormEvent) {
    e.preventDefault()
    if (FINAIS.includes(status) && status !== s.status &&
        !confirm(`Marcar como "${STATUS[status]}"? Esta mudança é definitiva.`)) return
    setEnviando(true)
    setErro('')
    const { error } = await supabase.from('solicitacoes').update({
      status,
      quantidade_adquirida: qtd === '' ? null : Number(qtd),
      previsao_entrega: previsao || null,
      justificativa: justificativa.trim() || null,
    }).eq('id', s.id)
    setEnviando(false)
    if (error) return setErro(mensagemErro(error))
    setSalvo(status === s.status ? 'Alterações salvas.' : `Status alterado para ${STATUS[status]}.`)
    aoSalvar()
  }

  return (
    <form className="formulario atender" onSubmit={salvar}>
      <h3>Atualizar atendimento</h3>
      <label>
        Status
        <select value={status} onChange={(e) => { setStatus(e.target.value as Status); setSalvo('') }}>
          <option value={s.status}>{STATUS[s.status]} (atual)</option>
          {PROXIMOS[s.status].map((p) => <option key={p} value={p}>{STATUS[p]}</option>)}
        </select>
      </label>
      {(pedeQtd || s.quantidade_adquirida !== null) && (
        <label>
          Quantidade adquirida{pedeQtd && ' *'}
          <input type="number" inputMode="numeric" min={0} step={1} required={pedeQtd}
            value={qtd} onChange={(e) => setQtd(e.target.value)} />
        </label>
      )}
      {!pedeJustificativa && (
        <label>
          Previsão de entrega
          <input type="date" value={previsao} onChange={(e) => setPrevisao(e.target.value)} />
        </label>
      )}
      <label>
        Justificativa{pedeJustificativa && ' *'}
        <textarea rows={3} required={pedeJustificativa} value={justificativa}
          onChange={(e) => setJustificativa(e.target.value)} />
      </label>
      <Erro>{erro}</Erro>
      {salvo && <p className="aviso" role="status">{salvo}</p>}
      <button className="botao primario" disabled={enviando}>
        {status === s.status ? 'Salvar alterações' : 'Salvar status'}
      </button>
    </form>
  )
}
