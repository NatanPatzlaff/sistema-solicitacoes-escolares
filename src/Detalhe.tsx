import { useEffect, useState, type FormEvent } from 'react'
import {
  FINAIS, PROXIMOS_SECRETARIA, STATUS, data, dataHora, dataSimples, mensagemErro, supabase,
  type Item, type Perfil, type Status,
} from './dominio'
import { BadgeCategoria, BadgeStatus, Erro, ResumoItens } from './ui'

type Cabecalho = { id: number; observacoes: string | null; criado_em: string; unidades: { nome: string } | null }

export function Detalhe({ id, perfil }: { id: number; perfil: Perfil }) {
  const secretaria = perfil.papel === 'secretaria'
  const [cab, setCab] = useState<Cabecalho | null | undefined>(undefined)
  const [itens, setItens] = useState<Item[]>([])
  const [atualizados, setAtualizados] = useState<Set<number>>(new Set())
  const [selecao, setSelecao] = useState<Set<number>>(new Set())
  const [painelAberto, setPainelAberto] = useState(false)
  const [erro, setErro] = useState('')
  const [aviso, setAviso] = useState('')

  async function carregar() {
    const [s, i] = await Promise.all([
      supabase.from('solicitacoes').select('id, observacoes, criado_em, unidades(nome)').eq('id', id).maybeSingle(),
      supabase.from('itens')
        .select('id, produto_id, categoria, item, quantidade, observacoes, status, justificativa, quantidade_adquirida, previsao_entrega, historico(id, status, alterado_por_nome, alterado_em)')
        .eq('solicitacao_id', id).order('id').order('alterado_em', { referencedTable: 'historico' }),
    ])
    setErro(mensagemErro(s.error ?? i.error))
    setCab(s.data as Cabecalho | null)
    const lista = (i.data ?? []) as Item[]
    setItens(lista)
    return lista
  }

  useEffect(() => {
    setSelecao(new Set())
    setAviso('')
    carregar().then(async (lista) => {
      if (secretaria || lista.length === 0) return
      // Gestor abriu a solicitação: guarda quais itens mudaram (para destacar) e apaga os avisos.
      const ids = lista.map((x) => x.id)
      const { data } = await supabase.from('novidades').select('item_id').in('item_id', ids)
      setAtualizados(new Set((data ?? []).map((n) => n.item_id as number)))
      if (data?.length) await supabase.from('novidades').delete().in('item_id', ids)
    })
  }, [id]) // eslint-disable-line react-hooks/exhaustive-deps

  if (cab === undefined) return erro ? <Erro>{erro}</Erro> : null
  if (cab === null) {
    return (
      <div className="vazio">
        <p>Solicitação não encontrada.</p>
        <a className="botao secundario" href="#/">Voltar para solicitações</a>
      </div>
    )
  }

  const porStatus: Partial<Record<Status, number>> = {}
  for (const x of itens) porStatus[x.status] = (porStatus[x.status] ?? 0) + 1
  const selecionados = itens.filter((x) => selecao.has(x.id))
  // Secretaria seleciona qualquer item; a escola só os adquiridos, para confirmar o recebimento.
  const marcavel = (x: Item) => secretaria || x.status === 'adquirida'
  const marcaveis = itens.filter(marcavel)
  const temMarcacao = marcaveis.length > 0

  function alternar(itemId: number) {
    const nova = new Set(selecao)
    if (!nova.delete(itemId)) nova.add(itemId)
    setSelecao(nova)
    setAviso('')
  }
  function selecionar(filtro: (x: Item) => boolean) {
    setSelecao(new Set(marcaveis.filter(filtro).map((x) => x.id)))
    setAviso('')
  }

  async function confirmarRecebimento() {
    const n = selecao.size
    if (!confirm(`Confirmar que ${n === 1 ? '1 item chegou' : `${n} itens chegaram`} na escola? A confirmação é definitiva.`)) return
    setErro('')
    const { error } = await supabase.rpc('atualizar_itens', { p_ids: [...selecao], p_status: 'entregue' })
    if (error) return setErro(mensagemErro(error))
    setSelecao(new Set())
    await carregar()
    setAviso(n === 1 ? 'Recebimento de 1 item confirmado.' : `Recebimento de ${n} itens confirmado.`)
  }

  return (
    <>
      <a className="voltar" href="#/" onClick={(e) => { if (history.length > 1) { e.preventDefault(); history.back() } }}>
        ← Solicitações
      </a>
      <div className="cabecalho-pagina">
        <h1>Solicitação nº {cab.id}</h1>
        <ResumoItens porStatus={porStatus} />
        <p className="suave">
          {cab.unidades?.nome} · cadastrada em {data(cab.criado_em)} · {itens.length} {itens.length === 1 ? 'item' : 'itens'}
        </p>
        {cab.observacoes && <p className="obs-geral">{cab.observacoes}</p>}
        {!secretaria && (
          <a className="botao secundario" href={`#/nova?base=${cab.id}`}>Repetir este pedido</a>
        )}
      </div>

      <Erro>{erro}</Erro>
      {aviso && <p className="aviso" role="status">{aviso}</p>}

      {secretaria && (
        <div className="selecao-rapida" role="group" aria-label="Selecionar itens">
          <span className="suave">Selecionar:</span>
          <button className="chip" onClick={() => selecionar((x) => !FINAIS.includes(x.status))}>Todos em aberto</button>
          {(['cadastrada', 'em_analise', 'adquirida'] as Status[]).filter((s) => porStatus[s]).map((s) => (
            <button key={s} className="chip" onClick={() => selecionar((x) => x.status === s)}>
              {STATUS[s]} ({porStatus[s]})
            </button>
          ))}
          {selecao.size > 0 && <button className="link" onClick={() => setSelecao(new Set())}>Limpar seleção</button>}
        </div>
      )}
      {!secretaria && temMarcacao && (
        <p className="dica">Chegou algum item na escola? Marque os itens adquiridos que foram recebidos e confirme.</p>
      )}

      <div className={secretaria ? 'area-atendimento' : ''}>
        <table className="tabela tabela-itens">
          <thead>
            <tr>
              {temMarcacao && (
                <th className="col-marcar">
                  <input type="checkbox" aria-label={secretaria ? 'Selecionar todos os itens' : 'Selecionar todos os itens adquiridos'}
                    checked={selecao.size > 0 && selecao.size === marcaveis.length}
                    ref={(el) => { if (el) el.indeterminate = selecao.size > 0 && selecao.size < marcaveis.length }}
                    onChange={(e) => selecionar(() => e.target.checked)} />
                </th>
              )}
              <th>Item</th>
              <th className="num">Pedido</th>
              <th className="num">Comprado</th>
              <th>Status</th>
              <th className="col-data">Previsão</th>
            </tr>
          </thead>
          <tbody>
            {itens.map((x) => (
              <tr key={x.id}
                className={`${atualizados.has(x.id) ? 'novo' : ''} ${selecao.has(x.id) ? 'selecionado' : ''} ${marcavel(x) ? 'marcavel' : ''}`}
                onClick={marcavel(x) ? () => alternar(x.id) : undefined}>
                {temMarcacao && (
                  <td className="col-marcar">
                    {marcavel(x) && (
                      <input type="checkbox" aria-label={`Selecionar ${x.item}`} checked={selecao.has(x.id)}
                        onClick={(e) => e.stopPropagation()} onChange={() => alternar(x.id)} />
                    )}
                  </td>
                )}
                <td className="col-item">
                  <span className="nome-item">{x.item}</span>
                  {atualizados.has(x.id) && <span className="sr"> (status atualizado)</span>}
                  <span className="info-item">
                    <BadgeCategoria categoria={x.categoria} />
                    {!x.produto_id && <span className="badge categoria">fora do catálogo</span>}
                    {x.observacoes && <span className="suave">{x.observacoes}</span>}
                  </span>
                  {x.justificativa && <span className="justificativa"><strong>Justificativa:</strong> {x.justificativa}</span>}
                  {x.historico.length > 0 && (
                    <details className="historico-item" onClick={(e) => e.stopPropagation()}>
                      <summary>Histórico</summary>
                      <ol>
                        {x.historico.map((h) => (
                          <li key={h.id}>{STATUS[h.status]} · {dataHora(h.alterado_em)} · {h.alterado_por_nome}</li>
                        ))}
                      </ol>
                    </details>
                  )}
                </td>
                <td className="num col-qtd" data-rotulo="Pedido ">{x.quantidade}</td>
                <td className={`num col-comprado ${x.quantidade_adquirida !== null && x.quantidade_adquirida !== x.quantidade ? 'diferente' : ''}`}
                  data-rotulo="Comprado ">
                  {x.quantidade_adquirida ?? '—'}
                </td>
                <td className="col-status"><BadgeStatus status={x.status} /></td>
                <td className="col-data" data-rotulo="Previsão ">{x.previsao_entrega ? dataSimples(x.previsao_entrega) : '—'}</td>
              </tr>
            ))}
          </tbody>
        </table>

        {!secretaria && selecao.size > 0 && (
          <button className="botao primario barra-confirmar" onClick={confirmarRecebimento}>
            Confirmar recebimento de {selecao.size} {selecao.size === 1 ? 'item' : 'itens'}
          </button>
        )}
        {secretaria && (
          <>
            {selecao.size > 0 && (
              <button className="botao primario barra-selecao" onClick={() => setPainelAberto(true)}>
                Atualizar {selecao.size} {selecao.size === 1 ? 'item' : 'itens'}
              </button>
            )}
            <Atendimento key={[...selecao].join(',')} itens={selecionados} aberto={painelAberto}
              aoFechar={() => setPainelAberto(false)}
              aoSalvar={async (msg) => {
                setPainelAberto(false)
                setSelecao(new Set())
                await carregar()
                setAviso(msg)
              }} />
            {painelAberto && <div className="veu" onClick={() => setPainelAberto(false)} />}
          </>
        )}
      </div>
    </>
  )
}

const MANTER = ''

// Painel da Secretaria: aplica status/quantidade/justificativa/previsão aos itens selecionados.
function Atendimento({ itens, aberto, aoFechar, aoSalvar }: {
  itens: Item[]
  aberto: boolean
  aoFechar: () => void
  aoSalvar: (msg: string) => void
}) {
  const unico = itens.length === 1 ? itens[0] : null
  const [status, setStatus] = useState<Status | typeof MANTER>(MANTER)
  const [qtd, setQtd] = useState(unico ? String(unico.quantidade_adquirida ?? unico.quantidade) : '')
  const [previsao, setPrevisao] = useState(unico?.previsao_entrega ?? '')
  const [justificativa, setJustificativa] = useState(unico?.justificativa ?? '')
  const [erro, setErro] = useState('')
  const [enviando, setEnviando] = useState(false)

  // Só oferece status para onde TODOS os selecionados podem ir.
  const opcoes = itens.length === 0 ? [] : (Object.keys(STATUS) as Status[])
    .filter((s) => itens.every((x) => PROXIMOS_SECRETARIA[x.status].includes(s)))
  const alvo = status || (unico?.status ?? null)
  const comprado = alvo === 'adquirida' || alvo === 'entregue'
  const pedeQtd = unico !== null && (comprado || unico.quantidade_adquirida !== null)
  const qtdMudou = unico !== null && pedeQtd && qtd !== '' && Number(qtd) !== unico.quantidade
  const pedeJustificativa = status === 'indisponivel' || status === 'nao_atendida' || qtdMudou
  const todosFinais = itens.length > 0 && itens.every((x) => FINAIS.includes(x.status))

  async function salvar(e: FormEvent) {
    e.preventDefault()
    if (status && FINAIS.includes(status) &&
        !confirm(`Marcar ${itens.length === 1 ? 'o item' : `${itens.length} itens`} como "${STATUS[status]}"? Esta mudança é definitiva.`)) return
    setEnviando(true)
    setErro('')
    const { error } = await supabase.rpc('atualizar_itens', {
      p_ids: itens.map((x) => x.id),
      p_status: status || null,
      p_quantidade_adquirida: pedeQtd && qtd !== '' ? Number(qtd) : null,
      p_justificativa: justificativa.trim() || null,
      p_previsao_entrega: previsao || null,
    })
    setEnviando(false)
    if (error) return setErro(mensagemErro(error))
    const quantos = itens.length === 1 ? '1 item atualizado' : `${itens.length} itens atualizados`
    aoSalvar(status ? `${quantos} para ${STATUS[status]}.` : `${quantos}.`)
  }

  return (
    <form className={`formulario painel-atendimento ${aberto ? 'aberto' : ''}`} onSubmit={salvar}
      onKeyDown={(e) => e.key === 'Escape' && aoFechar()}>
      <div className="painel-topo">
        <h2>Atualizar itens</h2>
        <button type="button" className="link fechar-painel" onClick={aoFechar}>Fechar</button>
      </div>
      {itens.length === 0 ? (
        <p className="suave">Selecione um ou mais itens na lista para mudar o status, a quantidade comprada ou registrar uma justificativa.</p>
      ) : todosFinais ? (
        <p className="suave">Os itens selecionados já estão em status final e não podem mais ser alterados.</p>
      ) : (
        <>
          <p className="suave">
            {unico ? <><strong>{unico.item}</strong> · pedido: {unico.quantidade}</> : `${itens.length} itens selecionados`}
          </p>
          <label>
            Novo status
            <select value={status} onChange={(e) => setStatus(e.target.value as Status | typeof MANTER)}>
              <option value={MANTER}>Manter o status atual</option>
              {opcoes.map((s) => <option key={s} value={s}>{STATUS[s]}</option>)}
            </select>
            {opcoes.length === 0 && itens.length > 1 && (
              <span className="dica">Os itens selecionados estão em etapas diferentes. Use “Selecionar” para pegar itens da mesma etapa.</span>
            )}
          </label>
          {pedeQtd && (
            <label>
              Quantidade comprada{comprado && ' *'}
              <input type="number" inputMode="numeric" min={0} step={1} required={comprado}
                value={qtd} onChange={(e) => setQtd(e.target.value)} />
            </label>
          )}
          {!unico && comprado && (
            <p className="dica">Cada item fica com a quantidade que foi pedida. Para comprar uma quantidade diferente, selecione só aquele item.</p>
          )}
          {(comprado || alvo === 'em_analise') && (
            <label>
              Previsão de entrega
              <input type="date" value={previsao} onChange={(e) => setPrevisao(e.target.value)} />
            </label>
          )}
          <label>
            Justificativa{pedeJustificativa && ' *'}
            <textarea rows={3} required={pedeJustificativa} value={justificativa}
              onChange={(e) => setJustificativa(e.target.value)}
              placeholder={qtdMudou ? 'Por que a quantidade mudou? Ex.: falta de verba.' : 'Motivo, visível para a escola.'} />
            {!unico && <span className="dica">A mesma justificativa vale para todos os itens selecionados.</span>}
          </label>
          <Erro>{erro}</Erro>
          <button className="botao primario" disabled={enviando}>
            {itens.length === 1 ? 'Salvar item' : `Aplicar a ${itens.length} itens`}
          </button>
        </>
      )}
    </form>
  )
}
