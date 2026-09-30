import { useRef, useState, type FormEvent } from 'react'
import { CATEGORIAS, mensagemErro, supabase } from './dominio'
import { Erro } from './ui'
import { lerLista } from './colarLista'

type Linha = { chave: number; categoria: string; item: string; quantidade: string; observacoes: string }

let proximaChave = 0
const linhaVazia = (categoria = ''): Linha =>
  ({ chave: proximaChave++, categoria, item: '', quantidade: '1', observacoes: '' })

export function Nova() {
  const [linhas, setLinhas] = useState<Linha[]>(() => [linhaVazia()])
  const [observacoes, setObservacoes] = useState('')
  const [erro, setErro] = useState('')
  const [enviando, setEnviando] = useState(false)
  const lista = useRef<HTMLOListElement>(null)
  const [colando, setColando] = useState(false)
  const [colado, setColado] = useState('')
  const [categoriaColada, setCategoriaColada] = useState('')
  const [avisoColagem, setAvisoColagem] = useState('')

  function aplicarColagem() {
    const novos = lerLista(colado).map((x) => ({ ...linhaVazia(categoriaColada), ...x, item: x.item.slice(0, 200) }))
    if (novos.length === 0) return
    const preenchidas = linhas.filter((l) => l.item.trim() || l.observacoes.trim())
    setLinhas([...preenchidas, ...novos])
    const semQtd = novos.filter((x) => !x.quantidade).length
    setAvisoColagem(`${novos.length} ${novos.length === 1 ? 'item adicionado' : 'itens adicionados'}. Confira categorias e quantidades`
      + (semQtd ? ` — ${semQtd} sem quantidade, preencha antes de enviar.` : '.'))
    setColado('')
    setColando(false)
  }

  const mudar = (chave: number, campo: keyof Linha, valor: string) =>
    setLinhas(linhas.map((l) => (l.chave === chave ? { ...l, [campo]: valor } : l)))

  function adicionar() {
    // A nova linha repete a categoria da anterior: as listas costumam vir agrupadas.
    setLinhas([...linhas, linhaVazia(linhas.at(-1)?.categoria)])
    requestAnimationFrame(() => lista.current?.querySelector<HTMLInputElement>('li:last-child .campo-item')?.focus())
  }

  async function enviar(e: FormEvent) {
    e.preventDefault()
    setEnviando(true)
    setErro('')
    // Unidade e status são definidos pelo banco a partir do gestor logado.
    const { data, error } = await supabase.rpc('criar_solicitacao', {
      p_observacoes: observacoes.trim() || null,
      p_itens: linhas.map((l) => ({
        categoria: l.categoria,
        item: l.item.trim(),
        quantidade: Number(l.quantidade),
        observacoes: l.observacoes.trim() || null,
      })),
    })
    setEnviando(false)
    if (error) return setErro(mensagemErro(error))
    location.hash = `#/solicitacao/${data}`
  }

  return (
    <>
      <div className="cabecalho-pagina"><h1>Nova solicitação</h1></div>
      <form className="formulario bloco" onSubmit={enviar}>
        <p className="suave">
          Inclua todos os itens do pedido. Se o item vem em embalagem, escreva no nome (ex.: “Luva M — caixa”).
        </p>
        {colando ? (
          <section className="colar" aria-label="Colar lista">
            <label>
              Cole a lista (um item por linha)
              <textarea rows={8} value={colado} onChange={(e) => setColado(e.target.value)} autoFocus
                placeholder={'20 água sanitária\n4 caixas álcool líquido\nLUVA M   200 CAIXAS'} />
            </label>
            <label>
              Categoria para estes itens (pode ajustar item a item depois)
              <select value={categoriaColada} onChange={(e) => setCategoriaColada(e.target.value)}>
                <option value="">Escolher depois</option>
                {Object.entries(CATEGORIAS).map(([v, n]) => <option key={v} value={v}>{n}</option>)}
              </select>
            </label>
            <div className="acoes">
              <button type="button" className="botao primario" onClick={aplicarColagem} disabled={!colado.trim()}>
                Adicionar itens da lista
              </button>
              <button type="button" className="botao secundario" onClick={() => setColando(false)}>Cancelar</button>
            </div>
          </section>
        ) : (
          <button type="button" className="botao secundario colar-botao" onClick={() => { setColando(true); setAvisoColagem('') }}>
            Colar lista
          </button>
        )}
        {avisoColagem && <p className="aviso" role="status">{avisoColagem}</p>}
        <ol className="linhas-itens" ref={lista}>
          {linhas.map((l, i) => (
            <li key={l.chave}>
              <fieldset className="linha-item">
                <legend>Item {i + 1}</legend>
                <label>
                  Categoria *
                  <select required value={l.categoria} onChange={(e) => mudar(l.chave, 'categoria', e.target.value)}>
                    <option value="" disabled>Selecione</option>
                    {Object.entries(CATEGORIAS).map(([v, n]) => <option key={v} value={v}>{n}</option>)}
                  </select>
                </label>
                <label>
                  Item *
                  <input className="campo-item" required maxLength={200} value={l.item}
                    onChange={(e) => mudar(l.chave, 'item', e.target.value)} placeholder="Ex.: papel sulfite A4 (resma)" />
                </label>
                <label className="campo-qtd">
                  Quantidade *
                  <input type="number" inputMode="numeric" required min={1} step={1} value={l.quantidade}
                    onChange={(e) => mudar(l.chave, 'quantidade', e.target.value)} />
                </label>
                <label className="campo-obs">
                  Observações
                  <input value={l.observacoes} onChange={(e) => mudar(l.chave, 'observacoes', e.target.value)}
                    placeholder="Modelo, cor, tamanho…" />
                </label>
                {linhas.length > 1 && (
                  <button type="button" className="link remover" onClick={() => setLinhas(linhas.filter((x) => x.chave !== l.chave))}
                    aria-label={`Remover item ${i + 1}`}>
                    Remover
                  </button>
                )}
              </fieldset>
            </li>
          ))}
        </ol>
        <button type="button" className="botao secundario adicionar" onClick={adicionar}>Adicionar item</button>
        <label>
          Observações gerais do pedido
          <textarea rows={3} value={observacoes} onChange={(e) => setObservacoes(e.target.value)}
            placeholder="Informações que valem para o pedido todo" />
        </label>
        <Erro>{erro}</Erro>
        <div className="acoes">
          <button className="botao primario" disabled={enviando}>
            Enviar solicitação ({linhas.length} {linhas.length === 1 ? 'item' : 'itens'})
          </button>
          <a className="botao secundario" href="#/">Cancelar</a>
        </div>
      </form>
    </>
  )
}
