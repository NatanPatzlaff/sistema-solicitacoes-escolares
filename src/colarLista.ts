// Transforma uma lista colada (uma linha por item) em itens do formulário.
// Aceita os formatos das listas reais das escolas:
//   "20 água sanitária"            → 20, "Água sanitária"
//   "4 caixa álcool líquido"       → 4,  "Álcool líquido", obs "4 caixa"
//   "LUVA M	200 CAIXAS"            → 200, "Luva m", obs "200 caixas"
//   "ÁLCOOL 70 30 CAIXAS COM 12 UNIDADES" → 30, "Álcool 70", obs "30 caixas com 12 unidades"
// Quando não acha a quantidade, deixa em branco para o gestor preencher (o campo é obrigatório).
// ponytail: heurística simples; o gestor sempre revisa antes de enviar.

export type ItemColado = { item: string; quantidade: string; observacoes: string }

const EMBALAGEM = String.raw`(?:cx|caixas?|caixinhas?|pacotes?|pacotinhos?|pcts?|pac|fardos?|rolos?|resmas?|kits?|gal[oõ]es|frascos?|latas?|sacos?|conjuntos?|estojos?|dz|d[uú]zias?)`
const UNIDADE = String.raw`(?:unidades?|unid|uni|un)`
const MEDIDA = `(?:${EMBALAGEM}|${UNIDADE})\\.?`

const NO_INICIO = new RegExp(`^(\\d+)(?:\\s*(${MEDIDA})\\s+(?:de\\s+)?|\\s+)(.+)$`, 'i')
const NO_FIM = new RegExp(`^(.+?)[\\s:–-]+(\\d+)\\s*(${MEDIDA})((?:\\s+(?:com|de)\\b.*)?)$`, 'i')
const SO_NUMERO_NO_FIM = /^(.+?)[\s:–-]+(\d+)$/

const ehUnidade = (m: string) => new RegExp(`^${UNIDADE}\\.?$`, 'i').test(m)

// Listas em CAIXA ALTA viram "Primeira maiúscula", mantendo tamanhos e siglas
// (M, G, AA, AAA, A4, GI-10): letra isolada, letra repetida ou palavra com número.
const manterMaiuscula = (p: string) =>
  /\d/.test(p) || (p.length === 1 && !/^[AEOÀÉ]$/.test(p)) || /^(\p{Lu})\1{1,2}$/u.test(p)

function capitalizar(s: string) {
  const texto = /\p{Ll}/u.test(s) ? s
    : s.split(' ').map((p) => (manterMaiuscula(p) ? p : p.toLowerCase())).join(' ')
  return texto.charAt(0).toUpperCase() + texto.slice(1)
}

export function lerLista(colado: string): ItemColado[] {
  return colado.split(/\r?\n/)
    .map((l) => l.replace(/^[\s•*·-]+/, '').replace(/\s+/g, ' ').trim())
    .filter(Boolean)
    .map((linha) => {
      let m = linha.match(NO_INICIO)
      if (m) {
        const [, qtd, medida, nome] = m
        return {
          item: capitalizar(nome),
          quantidade: qtd,
          observacoes: medida && !ehUnidade(medida) ? `${qtd} ${medida.toLowerCase()}` : '',
        }
      }
      m = linha.match(NO_FIM)
      if (m) {
        const [, nome, qtd, medida, resto] = m
        return {
          item: capitalizar(nome),
          quantidade: qtd,
          observacoes: ehUnidade(medida) && !resto ? '' : `${qtd} ${medida}${resto}`.toLowerCase(),
        }
      }
      m = linha.match(SO_NUMERO_NO_FIM)
      if (m) return { item: capitalizar(m[1]), quantidade: m[2], observacoes: '' }
      return { item: capitalizar(linha), quantidade: '', observacoes: '' }
    })
}
