# Checkout integrado

O fluxo atual usa `lib/checkout/commerce_api.dart` e `checkout_pages.dart`:

1. Produtos reais da API podem ser adicionados à sacola. O produto de demonstração não pode ser comprado.
2. Sacola permite aumentar, diminuir e remover quantidades, consultando o estoque do servidor.
3. Revisão mostra produtos, frete configurado pela loja, prazo e total do backend; solicita dados do pagador e endereço.
4. Confirmar cria o pedido e gera PIX. Erro de conexão mantém a mesma tentativa; um pedido já criado pode ser retomado pela sacola ou por **Meus pedidos** (ícone de recibo na Home).
5. QR Code e copia-e-cola são mostrados para pagamentos reais; sandbox aparece explicitamente como demonstração não pagável.
6. Consulta automática a cada 10 segundos enquanto a tela está ativa, consulta manual e atualização ao voltar do banco. Cancelamento pede confirmação. Estados aprovado, cancelado, recusado, reembolsado e em análise têm mensagens próprias.

A sessão é guardada em `flutter_secure_storage`. Visitantes possuem histórico da sessão local; usuários cadastrados recuperam sacola/pedidos ao entrar na conta, inclusive em outro aparelho. Veja [PAGES.md](PAGES.md) para cadastro, login e navegação. Cupons, rastreio e publicação nas lojas continuam separados.

## Executar

```powershell
flutter pub get
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000/api/v1
```

- Emulador Android: `10.0.2.2` aponta ao computador. HTTP liberado somente no manifesto de debug.
- Flutter Web local: `flutter run -d chrome --dart-define=API_BASE_URL=http://127.0.0.1:8000/api/v1`.
- Celular físico: use uma API HTTPS acessível. Não coloque token Mercado Pago, segredo do webhook ou token administrativo em `--dart-define`.
- Produção Web: origem HTTPS, HTTPS na API, `CORS_ORIGINS` no backend. Secure storage Web requer HTTPS ou localhost.
- Android: acesso à internet e backup de dados seguros desabilitado no manifesto. iOS/macOS: entitlements de Keychain incluídos; a assinatura final ainda exige o ambiente Apple.
- Linux: a implementação do armazenamento seguro exige as dependências nativas do pacote (`libsecret`).

## Testar

```powershell
flutter analyze
flutter test
flutter build web --dart-define=API_BASE_URL=https://sua-api/api/v1
```

O teste `backend_contract_test.dart` fica ignorado na execução comum. Para executá-lo com a API real local em sandbox, rode `tests/run_flutter_contract.py` na pasta do backend.

A compra agora depende do backend atualizado junto: chamadas antigas a `/payments/charges` foram retiradas. Veja [instruções do backend](../Lumen-backend/CHECKOUT.md) para frete, banco, webhook e manutenção de reservas.
