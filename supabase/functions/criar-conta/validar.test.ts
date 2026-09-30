// deno test supabase/functions/criar-conta
import assert from 'node:assert/strict'
import { validar } from './validar.ts'

const base = { nome: ' Maria ', email: ' Maria@Escola.COM ', senha: '12345678' }

Deno.test('gestor com escola existente', () => {
  assert.deepEqual(validar({ ...base, papel: 'gestor', unidade_id: '3' }), {
    nome: 'Maria', email: 'maria@escola.com', senha: '12345678', papel: 'gestor', unidade_id: 3, nova_unidade: null,
  })
})

Deno.test('gestor com escola nova ignora unidade_id', () => {
  const v = validar({ ...base, papel: 'gestor', unidade_id: 3, nova_unidade: ' EMEF Nova ' })
  assert.equal(typeof v === 'object' && v.nova_unidade, 'EMEF Nova')
  assert.equal(typeof v === 'object' && v.unidade_id, null)
})

Deno.test('Secretaria nunca recebe escola', () => {
  const v = validar({ ...base, papel: 'secretaria', unidade_id: 3, nova_unidade: 'X' })
  assert.equal(typeof v === 'object' && v.unidade_id, null)
  assert.equal(typeof v === 'object' && v.nova_unidade, null)
})

Deno.test('recusa dados inválidos', () => {
  assert.equal(validar(null), 'Informe o nome.')
  assert.equal(validar({ ...base, email: 'sem-arroba' }), 'E-mail inválido.')
  assert.equal(validar({ ...base, senha: '123' }), 'A senha provisória precisa ter pelo menos 8 caracteres.')
  assert.equal(validar({ ...base, papel: 'admin' }), 'Perfil inválido.')
  assert.equal(validar({ ...base, papel: 'gestor' }), 'Escolha a escola do gestor.')
})
