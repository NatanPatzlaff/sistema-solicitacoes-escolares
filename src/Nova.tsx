import { useRef, useState, type FormEvent } from 'react'
import { CATEGORIAS, mensagemErro, supabase } from './dominio'
import { Erro } from './ui'

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
