# Flutter Web na Vercel

Este projeto publica a interface Flutter no navegador. A API FastAPI é outro
projeto Vercel, conectado à Neon; Android e iOS continuam disponíveis no código.

## Publicação pelo Git

1. Envie as alterações deste repositório ao GitHub.
2. Na Vercel, **Add New > Project** e importe o repositório Flutter.
3. **Root Directory:** `.` para este repositório; `lumen-flutter` se usar monorepo.
4. **Framework Preset:** `Other`.
5. O `vercel.json` já define:
   - Install Command: `node --version` (não é um projeto npm).
   - Build Command: `node scripts/vercel-build.mjs`.
   - Output Directory: `build/web`.
6. Em **Environment Variables**, defina `API_BASE_URL`:
   `https://SUA-API.vercel.app/api/v1`.
7. Faça Deploy. Configure a origem exata obtida em `CORS_ORIGINS` do backend e
   faça Redeploy do backend.

O script instala Flutter **3.47.2**, compatível com Dart 3.13.2 do projeto, usa
`pubspec.lock` e incorpora somente a URL pública da API via `--dart-define`.
Se faltar a URL HTTPS, o build falha com uma mensagem em vez de publicar um app
apontando para localhost. Não configure banco Neon nem segredos de pagamento aqui.

A versão do SDK é fixa em `scripts/vercel-build.mjs`; ao atualizá-la, atualize e
valide também `pubspec.lock`. O build requer acesso ao GitHub e aos downloads do
Flutter/pub. Alterar `API_BASE_URL` exige um novo build/deploy. Variáveis definidas
somente no painel não mudam arquivos já publicados.

## Build local / Vercel Drop

```powershell
cd D:\Programas\lumen-eccomerce\lumen-flutter
flutter pub get --enforce-lockfile
flutter build web --release --dart-define=API_BASE_URL=https://SUA-API.vercel.app/api/v1
```

Publique somente `build/web`. Para atualizações automáticas, prefira importar
este repositório e usar o build configurado acima.

Para verificar o mesmo script do deploy usando seu SDK local:

```powershell
$env:FLUTTER_ROOT='C:/develop/flutter'
$env:API_BASE_URL='https://SUA-API.vercel.app/api/v1'
node scripts/vercel-build.mjs
```

`FLUTTER_ROOT` é apenas uma opção local; não configure o caminho Windows na Vercel.
Rotas web têm fallback para `index.html` e arquivos recebem revalidação de cache.
O título e o idioma da página estão configurados para Lumen/português.

## Verificar

```powershell
flutter analyze
flutter test
```

O teste de contrato completo é executado pelo backend:
`python tests/run_flutter_contract.py`, após `flutter pub get` no frontend.
Ele valida sandbox e o adaptador Mercado Pago Orders com um simulador HTTP local,
incluindo conta, estoque, PIX assíncrono, assinatura inválida e webhook repetido.
Não gera cobranças reais. No ambiente publicado, confira catálogo,
cadastro/login, sacola e PIX. Se o catálogo falhar, confira a URL da API, `/ready`,
CORS e proteção de deploy da Vercel. Não basta publicar o frontend para que as
funções que dependem do backend funcionem.

Para produção com Neon, migrations, manutenção e webhook, consulte
`DEPLOY_VERCEL.md` no repositório do backend.

Referências: [Flutter Web](https://docs.flutter.dev/deployment/web),
[configuração Vercel](https://vercel.com/docs/project-configuration).
