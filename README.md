<p align="center">
  <img src="assets/brand/lumen-github-header.svg" alt="Lumen - Vista sua essencia" width="760">
</p>

<p align="center">
  <strong>APLICATIVO FLUTTER</strong> &nbsp;•&nbsp; Experiência de compra feminina, elegante e personalizada.
</p>

<p align="center">
  <img src="https://img.shields.io/badge/FLUTTER-D9B66A?style=flat-square&logo=flutter&logoColor=171717" alt="Flutter">
  <img src="https://img.shields.io/badge/STATUS-EM%20CONSTRU%C3%87%C3%83O-171717?style=flat-square&labelColor=171717&color=D9B66A" alt="Status: em construção">
  <img src="https://img.shields.io/badge/PLATAFORMAS-ANDROID%20%7C%20IOS-171717?style=flat-square&labelColor=171717&color=D9B66A" alt="Android e iOS">
</p>

Aplicativo Flutter da Lumen, uma loja digital feminina com uma experiência editorial, leve e personalizada.

> **Vista a sua essência.**

## ✦ Estado atual

A primeira demonstração navegável está pronta. Ela apresenta uma tela de entrada animada e uma Home com um produto fictício, o **Vestido Aura**.

- Identidade visual preta e dourada inspirada na marca;
- Animação de entrada com transição para a Home;
- Vitrine inicial com produto, preço e selo de exclusividade;
- Favoritos, sacola com contador e navegação inferior;
- Home conectada ao catálogo FastAPI, com loading, erro, nova tentativa e fallback demonstrativo.

## ✦ Tecnologias

- Flutter e Dart;
- Material 3;
- Android, iOS, Web, Windows, macOS e Linux a partir da base Flutter.

## ✦ Como executar

Pré-requisitos: Flutter instalado e um emulador/dispositivo conectado.

```powershell
cd lumen-flutter
flutter pub get
flutter run
```

### API local

Com o backend iniciado, o emulador Android usa por padrão `http://10.0.2.2:8000/api/v1`. Para outro destino, informe a URL na inicialização:

```powershell
# Chrome ou simulador iOS
flutter run --dart-define=API_BASE_URL=http://127.0.0.1:8000/api/v1

# Celular físico: substitua pelo IP local da máquina que executa a API
flutter run --dart-define=API_BASE_URL=http://192.168.0.10:8000/api/v1
```

Para verificar o código:

```powershell
flutter analyze
flutter test
```

## ✦ Estrutura atual

```text
lib/
  main.dart       # tema, animação de entrada, Home e produto demonstrativo
test/
  widget_test.dart
```

## ✦ Cronograma do frontend

| Etapa | Entrega | Status |
| --- | --- | --- |
| 1. Fundamentos visuais | Tema, identidade Lumen, tela de entrada e Home | Concluída |
| 2. Base de integração | Ambientes, cliente HTTP, carregamento, erro, nova tentativa e fallback local | Concluída |
| 3. Descoberta e catálogo | Produtos reais, categorias, busca, filtros, paginação, banners e favoritos | Planejada |
| 4. Produto e sacola | Detalhe, fotos, variações, disponibilidade, quantidade, preço e persistência do carrinho | Planejada |
| 5. Conta da cliente | Cadastro, login, recuperação de senha, perfil, endereços e preferências | Planejada |
| 6. Checkout | Endereço, opções de entrega, cupom, resumo, pagamento e confirmação do pedido | Planejada |
| 7. Pós-compra | Histórico, rastreio, cancelamento dentro das regras e atendimento | Planejada |
| 8. Qualidade de experiência | Acessibilidade, responsividade, estados offline, notificações, analytics e relatório de falhas | Planejada |
| 9. Segurança e privacidade | Armazenamento seguro de token, consentimento, telas legais e política de privacidade | Planejada |
| 10. Publicação Android | Ícone, assinatura, App Bundle, testes internos/fechados, ficha e envio à Google Play | Planejada |
| 11. Publicação iOS | Identificador, certificados, ícones, TestFlight, ficha e envio à App Store | Planejada |

## ✦ Critérios para lançamento mobile

Antes de publicar, a aplicação deve concluir uma compra ponta a ponta em ambiente de homologação, apresentar mensagens claras para erro e indisponibilidade, não expor dados sensíveis em logs e ser testada em dispositivos Android e iOS reais.

Também serão necessários os materiais da loja: ícone final, capturas de tela, descrição, categoria, e-mail de suporte, URL de política de privacidade, classificação indicativa e declarações de dados/permissões exigidas por cada loja.

## ✦ Próximo passo

Criar a tela de detalhe do produto e permitir selecionar variações e quantidade antes de persistir a sacola. A Home já consome `GET /api/v1/products`; o Vestido Aura local só aparece quando a API está indisponível.

## ✦ Identidade

A Lumen usa fundo escuro, tons dourados e uma tipografia arejada para reforçar uma experiência elegante, acolhedora e focada em descoberta.
