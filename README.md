# Lumen - Aplicativo

Aplicativo Flutter da Lumen, uma loja digital feminina com uma experiência editorial, leve e personalizada.

> **Vista a sua essência.**

## Estado atual

A primeira demonstração navegável está pronta. Ela apresenta uma tela de entrada animada e uma Home com um produto fictício, o **Vestido Aura**.

- Identidade visual preta e dourada inspirada na marca;
- Animação de entrada com transição para a Home;
- Vitrine inicial com produto, preço e selo de exclusividade;
- Favoritos, sacola com contador e navegação inferior;
- Interface funcional sem depender do backend para a demonstração inicial.

## Tecnologias

- Flutter e Dart;
- Material 3;
- Android, iOS, Web, Windows, macOS e Linux a partir da base Flutter.

## Como executar

Pré-requisitos: Flutter instalado e um emulador/dispositivo conectado.

```powershell
cd lumen_store
flutter pub get
flutter run
```

Para verificar o código:

```powershell
flutter analyze
flutter test
```

## Estrutura atual

```text
lib/
  main.dart       # tema, animação de entrada, Home e produto demonstrativo
test/
  widget_test.dart
```

## Cronograma do frontend

| Etapa | Entrega | Status |
| --- | --- | --- |
| 1. Fundamentos visuais | Tema, identidade Lumen, tela de entrada e Home | Concluída |
| 2. Catálogo real | Consumir a API, loading, erro e estado vazio | Próxima |
| 3. Produto e sacola | Detalhe, tamanho/cor, quantidade e persistência | Planejada |
| 4. Conta e pedidos | Login, perfil, endereços e pedidos | Planejada |
| 5. Checkout e qualidade | Pagamento, testes de jornada e publicação | Planejada |

## Próximo passo

Conectar a Home ao endpoint `GET /api/v1/products` do projeto backend. O produto atual é intencionalmente local para que a interface possa ser apresentada mesmo com a API desligada.

## Identidade

A Lumen usa fundo escuro, tons dourados e uma tipografia arejada para reforçar uma experiência elegante, acolhedora e focada em descoberta.
