// Cria conta de gestor ou da Secretaria. Roda no Supabase (Edge Function, plano gratuito),
// porque criar usuários exige a chave service_role, que nunca pode ir para o site.
// Só atende quem já é da Secretaria.
import { createClient } from 'npm:@supabase/supabase-js@2'
import { validar } from './validar.ts'

const cors = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}
const resposta = (status: number, corpo: unknown) =>
  new Response(JSON.stringify(corpo), { status, headers: { ...cors, 'Content-Type': 'application/json' } })

async function atender(req: Request) {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: cors })
  if (req.method !== 'POST') return resposta(405, { erro: 'Método não permitido.' })

  const url = Deno.env.get('SUPABASE_URL')!
  const chamador = createClient(url, Deno.env.get('SUPABASE_ANON_KEY')!, {
    global: { headers: { Authorization: req.headers.get('Authorization') ?? '' } },
  })
  const { data: papel } = await chamador.rpc('meu_papel')
  if (papel !== 'secretaria') return resposta(403, { erro: 'Apenas a Secretaria cria contas.' })

  const v = validar(await req.json().catch(() => null))
  if (typeof v === 'string') return resposta(400, { erro: v })

  const admin = createClient(url, Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!, {
    auth: { persistSession: false },
  })
  const { data: criado, error } = await admin.auth.admin.createUser({
    email: v.email, password: v.senha, email_confirm: true,
  })
  if (error) {
    const existe = /already|registered|exists/i.test(error.message)
    return resposta(400, { erro: existe ? 'Já existe uma conta com este e-mail.' : error.message })
  }

  // Se algo falhar daqui em diante, desfaz o usuário para não sobrar conta sem perfil.
  const desfazer = async (msg: string) => {
    await admin.auth.admin.deleteUser(criado.user.id)
    return resposta(500, { erro: `${msg} Nada foi salvo.` })
  }
  let unidade_id = v.unidade_id
  if (v.nova_unidade) {
    const { data, error } = await admin.from('unidades')
      .upsert({ nome: v.nova_unidade }, { onConflict: 'nome' }).select('id').single()
    if (error) return desfazer('Não foi possível criar a escola.')
    unidade_id = data.id
  }
  const { error: erroPerfil } = await admin.from('perfis').insert({
    id: criado.user.id, nome: v.nome, email: v.email, papel: v.papel, unidade_id,
  })
  if (erroPerfil) return desfazer('Não foi possível criar o perfil.')

  return resposta(200, { id: criado.user.id })
}

Deno.serve(atender)
