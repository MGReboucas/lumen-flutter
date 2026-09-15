# Páginas e conta

- **Início:** vitrine real; tocar na imagem abre o detalhe. Se a API falhar, aparece erro com nova tentativa, sem simular produtos disponíveis.
- **Categorias:** busca por nome, filtro por categoria, paginação, produtos esgotados e estado vazio.
- **Detalhe:** descrição, preço, disponibilidade, quantidade, adicionar à sacola e favoritar. Ilustrações são identificadas como ilustrativas; fotos reais ainda dependem do catálogo.
- **Favoritos:** persistidos neste aparelho para visitante ou no backend para uma conta. Listas de visitante e conta são separadas.
- **Perfil:** cadastro/login, e-mail da conta, pedidos e logout com confirmação.
- **Cadastro/login:** validação, confirmação da senha no cadastro, mostrar/ocultar senha, mensagens da API e bloqueio de envio repetido. Senhas de 12 a 128 caracteres.
- Sacola, checkout, PIX e histórico continuam integrados. A primeira conta pode assumir a sacola visitante; uma conta existente retoma sua própria sacola.

## Rodar no navegador

Atualize também o backend com `alembic upgrade head` e reinicie a API. Para o navegador local, o endereço padrão agora é `http://localhost:8000/api/v1` (ou `127.0.0.1`, conforme a página).

```powershell
flutter pub get
flutter run -d chrome
```

## Rodar no telefone Android

Telefone e computador na mesma rede; backend escutando em `0.0.0.0:8000`, porta liberada somente para a rede privada. Troque o exemplo pelo IP real do computador:

```powershell
flutter run --dart-define=API_BASE_URL=http://192.168.0.10:8000/api/v1
```

`localhost` no telefone aponta para o próprio telefone. `10.0.2.2` vale para o emulador Android, não para aparelho físico. HTTP está habilitado apenas em debug Android. Para release/iPhone, use API HTTPS acessível. Uma alteração de `--dart-define` exige reiniciar o app, não apenas hot reload.

No Web de produção, configure `API_BASE_URL` e `CORS_ORIGINS`; sem override, o aplicativo usa `/api/v1` na mesma origem HTTPS. Não coloque nenhuma credencial de pagamento nos parâmetros do Flutter.

## Verificar

```powershell
flutter analyze
flutter test
flutter build web --dart-define=API_BASE_URL=https://sua-api/api/v1
```

Os testes incluem navegação em viewport de telefone, detalhe/favoritos, validação de cadastro, login, restauração de sessão e logout. Teste de aparelho nativo ainda deve ser feito no seu telefone. As funções de e-mail (confirmação e recuperação de senha) não estão implementadas.
