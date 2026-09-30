// deno test src/colarLista.test.ts
import assert from 'node:assert/strict'
import { lerLista } from './colarLista.ts'

const um = (linha: string) => lerLista(linha)[0]

Deno.test('quantidade no início (lista manuscrita da Cinderela)', () => {
  assert.deepEqual(um('20 água sanitária'), { item: 'Água sanitária', quantidade: '20', observacoes: '' })
  assert.deepEqual(um('4 caixa álcool líquido'), { item: 'Álcool líquido', quantidade: '4', observacoes: '4 caixa' })
  assert.deepEqual(um('5 fardos sacos de lixo 15 L'), { item: 'Sacos de lixo 15 L', quantidade: '5', observacoes: '5 fardos' })
  assert.deepEqual(um('3cx bom ar'), { item: 'Bom ar', quantidade: '3', observacoes: '3 cx' })
})

Deno.test('quantidade no fim (tabelas em PDF)', () => {
  assert.deepEqual(um('LUVA M\t200 CAIXAS'), { item: 'Luva M', quantidade: '200', observacoes: '200 caixas' })
  assert.deepEqual(um('PILHA ALCALINA AAA 20 CAIXAS COM 10'), { item: 'Pilha alcalina AAA', quantidade: '20', observacoes: '20 caixas com 10' })
  assert.deepEqual(um('FOLHA A4 120 50 PAC.'), { item: 'Folha A4 120', quantidade: '50', observacoes: '50 pac.' })
  assert.deepEqual(um('CANETA PRETA E AZUL 2'), { item: 'Caneta preta e azul', quantidade: '2', observacoes: '' })
  assert.deepEqual(um('ÁGUA SANITÁRIA 5 LITROS 100 UNIDADES'), { item: 'Água sanitária 5 litros', quantidade: '100', observacoes: '' })
  assert.deepEqual(um('ÁLCOOL LÍQUIDO 70 30 CAIXAS COM 12 UNIDADES'),
    { item: 'Álcool líquido 70', quantidade: '30', observacoes: '30 caixas com 12 unidades' })
  assert.deepEqual(um('BORRACHA 250 UNI'), { item: 'Borracha', quantidade: '250', observacoes: '' })
  assert.deepEqual(um('Régua - 250'), { item: 'Régua', quantidade: '250', observacoes: '' })
})

Deno.test('sem quantidade: fica em branco para o gestor preencher', () => {
  assert.deepEqual(um('ALFINETES --'), { item: 'Alfinetes --', quantidade: '', observacoes: '' })
})

Deno.test('ignora linhas vazias e marcadores', () => {
  assert.equal(lerLista('\n • 2 grampeadores\n\n- 10 clipes\n').length, 2)
})
