# 🍫 Bella Lu Doces — Plataforma E-Commerce & Painel Gestor (Web + Android APK)

> **Nota para Agentes de IA (Gemini 4 Argon / Antigravity / Cursor):**
> Todo o raciocínio arquitetural, integrações de nuvem, regras de negócio e fluxo de deploy estão detalhados em [`GEMINI.md`](./GEMINI.md) e abaixo. Leia antes de iniciar qualquer modificação.

---

## ⚠️ Regra de Ouro do Fluxo de Trabalho
1. **NUNCA execute deploy no Firebase Hosting ou publicação de Release do APK sem antes:**
   - Implementar a alteração solicitada;
   - Rodar `flutter test` e garantir que 100% dos testes passem;
   - Apresentar o resultado ao usuário e **aguardar o comando explícito** (*"prossiga"*, *"pode fazer deploy"*).
2. **Idioma:** Comunicação sempre em **Português (pt-BR)**.

---

## 🌐 Links Oficiais em Produção

| Ambiente / Canal | URL Oficial |
| :--- | :--- |
| **Vitrine Pública (Clientes)** | `https://www.bellaludoces.com.br` / `https://bellaludoces.com.br` |
| **Painel Admin (Web)** | `https://www.bellaludoces.com.br/painel/` |
| **Download Direto do APK (Mais Recente)** | `https://github.com/bellaludocess-maker/bellalu-apk/releases/latest/download/BellaLu_Painel_Admin.apk` |
| **Repositório Privado (Código-Fonte)** | `https://github.com/bellaludocess-maker/Bellaludoces` |
| **Repositório Público de Releases (APK)** | `https://github.com/bellaludocess-maker/bellalu-apk` |
| **Cloudflare Worker (InfinitePay API + Webhook)** | `https://bellalu-infinitepay.bellaludocess.workers.dev` |

---

## 🏗️ Arquitetura e Módulos (`lib/`)

O sistema utiliza **dois entrypoints independentes** compartilhando o mesmo núcleo de dados em tempo real:
- **`lib/main.dart`**: Vitrine Pública para os clientes da loja.
- **`lib/main_admin.dart`**: Painel Administrativo exclusivo da proprietária (protegido por PIN, padrão `2026`).

### Principais Módulos:
- **Módulo 0 (`lib/core/`)**:
  - [`app_constants.dart`](lib/core/constants/app_constants.dart): Constantes globais, chaves públicas do Firebase (`bellaludoces`), Cloudinary (`aq9vse7p` / `bella_lu_preset`), InfinitePay (`$lucineide-silva-jan`) e contatos da **Sunflower Development**.
  - [`sunflower_developer_badge.dart`](lib/core/widgets/sunflower_developer_badge.dart): Selo interativo e cartão digital da desenvolvedora **Sunflower Development** presente no rodapé da vitrine, na tela de login do painel e no rodapé do painel admin.
- **Módulo 1 (`lib/modules/catalog/`)**:
  - Catálogo reativo, filtro por categorias dinâmicas, busca por nome/sabor, modelo de produtos ([`product_model.dart`](lib/modules/catalog/models/product_model.dart)) e modelo de cupons de desconto ([`coupon_model.dart`](lib/modules/catalog/models/coupon_model.dart)).
- **Módulo 2 (`lib/modules/cart/`)**:
  - Sacola de compras com suporte a múltiplos tamanhos/pacotes, sabores e observações por item.
- **Módulo 3 (`lib/modules/checkout/`)**:
  - Alternância entre **Entrega em Domicílio** (com taxa dinâmica configurável no painel) e **Retirada**.
  - Aplicação de **Cupons de Desconto** (`% Porcentagem`, `R$ Valor Fixo` ou `Frete Grátis`), com validação de pedido mínimo e uso único por telefone do cliente.
  - Pagamento via **Pix Manual (copia e cola)** ou **Checkout Integrado InfinitePay (Pix / Cartão)** + envio formatado para o WhatsApp da loja (`(34) 99116-8044`).
- **Módulo 4 (`lib/modules/external/`)**:
  - [`firestore_catalog_repository.dart`](lib/modules/external/firebase/firestore_catalog_repository.dart): Persistência em nuvem no **Cloud Firestore** (`products`, `categories`, `orders`, `coupons`, `store_settings/pix_config`, `store_settings/delivery_config`, `store_settings/admin_security`).
  - [`cloudinary_service.dart`](lib/modules/external/cloudinary/cloudinary_service.dart): Upload e otimização automática de fotos de produtos.
- **Módulo 5 (`lib/modules/admin/`)**:
  - [`admin_screen.dart`](lib/modules/admin/views/admin_screen.dart): Gestão completa de produtos, categorias, pedidos recebidos (com abas *Em Aberto*, *Histórico* e exclusão individual ou em lote), Chave Pix, Taxa de Entrega, Cupons de Desconto, PIN de segurança e **Atualizador Automático de APK via GitHub Releases**.

---

## 🚀 Comandos Rápidos de Build, Release de APK e Deploy

Consulte a seção 5 do arquivo [`GEMINI.md`](./GEMINI.md) para a sequência exata de comandos PowerShell para:
1. Executar os testes (`flutter test`);
2. Compilar a Vitrine Web e o Painel Web (`/painel/`);
3. Gerar o APK (`BellaLu_Painel_Admin.apk`) e publicar automaticamente no GitHub Releases via [`scripts/publish_apk_release.ps1`](scripts/publish_apk_release.ps1);
4. Fazer o deploy no Firebase Hosting (`npx firebase-tools deploy --only hosting --project bellaludoces`).
