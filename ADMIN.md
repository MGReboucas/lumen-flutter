# Painel administrativo

Depois de liberar a conta no backend, entre novamente e abra
**Perfil → Administrar loja**. A entrada só aparece para administradores; a API
também verifica a permissão em cada consulta e alteração.

O painel permite buscar produtos ativos/inativos, cadastrar e editar nome,
descrição, preço, estoque disponível, categoria e uma foto principal por link
HTTPS. É possível criar categorias, desativar e reativar produtos.

O preço aceita vírgula ou ponto com até duas casas decimais. A foto deve estar
hospedada em um endereço público; esta versão não faz upload de arquivos.
Se o estoque ou produto mudar durante a edição, o painel solicita a recarga dos
dados antes de permitir um novo salvamento.

## Publicação

O backend precisa da migração `0004_admin_catalog` e das rotas `/api/v1/admin`.
Primeiro aplique a migração no banco, depois publique o backend e este frontend.
Consulte `ADMIN.md` no backend para os comandos de migração e liberação/revogação
da conta. Nenhum segredo administrativo deve ser configurado no frontend.

## Testes

```powershell
flutter test test/admin_test.dart
flutter analyze
```

Os testes verificam acesso por perfil, bloqueio de clientes comuns, cadastro de
produto/categoria em tela de celular, preço em centavos e tratamento de conflito
de estoque. Os testes de compra continuam disponíveis no script do backend.

Gestão administrativa de pedidos, envio e rastreio será uma entrega separada.
