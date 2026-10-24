# 🧠 Contexto Completo, Raciocínio e Guia de Continuidade — Bella Lu Doces

> **Instrução para a IA (Gemini 4 Argon / Antigravity / Cursor):**
> Este arquivo contém toda a memória arquitetural, regras de negócio, integrações em nuvem, histórico de decisões técnicas e fluxo de deploy do projeto **Bella Lu Doces**. Leia este documento integralmente antes de executar qualquer alteração.

---

## ⚠️ REGRA DE OURO DO USUÁRIO (OBRIGATÓRIA)
1. **NUNCA execute deploy no Firebase Hosting ou publicação de Release do APK sem antes:**
   - Implementar a alteração solicitada;
   - Rodar `flutter test` e garantir que todos os testes passem;
   - Apresentar o resumo ao usuário e **aguardar o comando explícito** (*"prossiga"*, *"pode fazer deploy"*).
2. **Idioma:** Responda sempre em **Português (pt-BR)**, de forma clara, direta e objetiva.

---

## 1. Visão Geral da Arquitetura Dual (Vitrine Web + Painel Admin Web/APK)

O projeto possui **dois entrypoints independentes** compilados a partir da mesma base Flutter (`F:\BellaLu`):

1. **Vitrine Pública de Clientes (`lib/main.dart`)**
   - **URLs em Produção:** `https://www.bellaludoces.com.br` e `https://bellaludoces.com.br` (também espelhado em `https://bellaludoces.web.app`).
   - **Público-alvo:** Clientes finais fazendo pedidos pelo celular ou computador.
   - **Funcionalidades:**
     - Banner Hero com selo da **Taxa de Entrega dinâmica** (vinda do Firebase) e link para o Instagram `@Bellalu.doces` (os botões soltos de WhatsApp foram removidos intencionalmente da vitrine porque os pedidos são feitos 100% pelo fluxo web do site).
     - Filtro por categorias dinâmicas e busca por nome/sabor.
     - Seleção de tamanho/pacote (ex.: Tradicional R$ 20,00 vs Especial R$ 25,00), sabores e observações.
     - Sacola flutuante e Checkout completo (`lib/modules/checkout/views/checkout_screen.dart`).
     - Rodapé com link do Instagram da loja e o selo interativo da desenvolvedora (**Sunflower Development**).

2. **Painel Administrativo Exclusivo da Loja (`lib/main_admin.dart`)**
   - **URL em Produção (Web):** `https://www.bellaludoces.com.br/painel/`
   - **Aplicativo Android (APK):** `BellaLu_Painel_Admin.apk` (hospedado e atualizado via GitHub Releases em `bellaludocess-maker/bellalu-apk`).
   - **Proteção:** Portão de login por PIN (`lib/modules/admin/views/admin_login_gate.dart`, PIN padrão `2026`, alterável pelo próprio painel e salvo no Firestore).
   - **Funcionalidades (`lib/modules/admin/views/admin_screen.dart`):**
     - **Cadastrar Novo Produto** (com upload direto de foto da galeria para o Cloudinary).
     - **Editar ou Excluir Produtos Cadastrados** em janela pop-up + chave liga/desliga de *Disponível / Esgotado* em tempo real.
     - **Criar e Gerenciar Categorias** do cardápio.
     - **Pedidos Recebidos com Histórico e Exclusão**:
       - Abas de filtro: `Em Aberto`, `Histórico` (concluídos) e `Todos`.
       - Chave `Switch` em cada pedido para marcar como concluído (move para o Histórico).
       - Botão de lixeira (`🗑️`) individual em cada pedido para apagar pedidos de teste ou antigos do Firestore.
       - Botão `Limpar Histórico` para apagar todos os pedidos concluídos de uma só vez.
     - **Configuração da Chave Pix da Loja** (Chave, Nome do Titular e Banco).
     - **Taxa de Entrega Dinâmica** (altera o valor do frete em tempo real na vitrine e no Checkout).
     - **Cupons de Desconto / Fidelidade** (cria cupons em `% Porcentagem`, `R$ Valor Fixo` ou `Frete Grátis`, com pedido mínimo opcional e trava de **uso único por telefone do cliente**).
     - **Segurança do Painel** (alteração do PIN de acesso).
     - **Atualizador Automático via GitHub Releases** (verifica na abertura se há nova versão no repositório `bellalu-apk` e exibe aviso para baixar e atualizar com 1 toque).

---

## 2. Mapa de Arquivos e Módulos (`lib/`)

- [`lib/core/constants/app_constants.dart`](lib/core/constants/app_constants.dart): Todas as constantes globais, IDs do Firebase, Cloudinary, InfinitePay, URLs de atualização do APK e contatos da **Sunflower Development**.
- [`lib/core/theme/bella_colors.dart`](lib/core/theme/bella_colors.dart) & [`lib/core/theme/bella_theme.dart`](lib/core/theme/bella_theme.dart): Paleta confeitaria artesanal (rosa suave, chocolate escuro, creme) e tipografia.
- [`lib/core/widgets/sunflower_developer_badge.dart`](lib/core/widgets/sunflower_developer_badge.dart): Selo e modal digital interativo da desenvolvedora **Sunflower Development** com logo (`assets/images/sunflower_logo.png`) e 3 contatos de WhatsApp (`(34) 99990-8727`, `(34) 99938-7854`, `(34) 99684-6299`).
- [`lib/modules/catalog/models/product_model.dart`](lib/modules/catalog/models/product_model.dart): Modelo de produto com preço base, segundo preço opcional, grupos de opções e disponibilidade.
- [`lib/modules/catalog/models/coupon_model.dart`](lib/modules/catalog/models/coupon_model.dart): Modelo de cupom de desconto (`percentage`, `fixed`, `free_shipping`), validação de pedido mínimo e controle de telefones que já utilizaram (`usedByPhones`).
- [`lib/modules/catalog/controllers/catalog_controller.dart`](lib/modules/catalog/controllers/catalog_controller.dart): `ChangeNotifier` central que sincroniza produtos, categorias, pedidos, Pix, taxa de entrega, cupons e PIN com o repositório.
- [`lib/modules/external/firebase/firestore_catalog_repository.dart`](lib/modules/external/firebase/firestore_catalog_repository.dart): Integração REST direta com o **Cloud Firestore** (sem depender de plugins nativos pesados que quebram entre Web/Android), com prioridade sempre para os dados remotos da nuvem e fallback local.
- [`lib/modules/external/cloudinary/cloudinary_service.dart`](lib/modules/external/cloudinary/cloudinary_service.dart): Upload unsigned de imagens com otimização automática (`f_auto,q_auto,w_900`).
- [`lib/modules/checkout/services/infinitepay_checkout_service.dart`](lib/modules/checkout/services/infinitepay_checkout_service.dart): Integração com o Checkout da **InfinitePay** (`$lucineide-silva-jan`) via Cloudflare Worker (`https://bellalu-infinitepay.bellaludocess.workers.dev`), enviando itens em centavos (ou valor líquido consolidado quando há cupom de desconto aplicado).
- [`lib/modules/checkout/services/whatsapp_order_service.dart`](lib/modules/checkout/services/whatsapp_order_service.dart): Formatação completa do pedido para envio ao WhatsApp oficial da loja (`5534991168044`).
- [`cloudflare-worker/worker.js`](cloudflare-worker/worker.js): Código do Worker publicado na Cloudflare que faz a ponte segura entre o site, a API de links da InfinitePay (`/create-checkout`) e o Webhook automático (`/webhook` -> marca o pedido como pago no Firestore).

---

## 3. Integrações de Nuvem e Infraestrutura

### 3.1. Firebase (`bellaludoces`)
- **Project ID:** `bellaludoces`
- **Conta Google autenticada no Firebase CLI:** `bellaludocess@gmail.com`
  - Caso o Firebase CLI dê erro 401/permissão por múltiplas contas no PC, rode:
    `npx firebase-tools login:use bellaludocess@gmail.com`
- **Coleções no Cloud Firestore:**
  - `products`: Documentos dos produtos do catálogo.
  - `categories`: Categorias do cardápio.
  - `orders`: Pedidos gerados no Checkout.
  - `coupons`: Cupons de desconto criados no painel.
  - `store_settings/pix_config`: `{ pixKey, pixHolderName, pixBankName }`
  - `store_settings/delivery_config`: `{ deliveryFee }`
  - `store_settings/admin_security`: `{ adminPin }`

### 3.2. Cloudinary (Upload de Fotos dos Produtos)
- **Cloud Name:** `aq9vse7p`
- **Upload Preset (Unsigned):** `bella_lu_preset`

### 3.3. InfinitePay + Cloudflare Worker
- **InfiniteTag (Handle):** `lucineide-silva-jan`
- **Cloudflare Worker URL:** `https://bellalu-infinitepay.bellaludocess.workers.dev`
- **Redirect URL pós-pagamento:** `https://www.bellaludoces.com.br/` (o `lib/main.dart` detecta automaticamente `order_nsu`, `receipt_url` e `transaction_nsu` na URL de retorno, marca o pedido como concluído e exibe modal para envio do comprovante no WhatsApp).

### 3.4. Domínio Customizado (Registro.br)
- **Domínios ativos com SSL no Firebase Hosting:**
  - `bellaludoces.com.br`
  - `www.bellaludoces.com.br`

### 3.5. Repositórios GitHub (`bellaludocess-maker`)
1. **Código-fonte Privado:** `https://github.com/bellaludocess-maker/Bellaludoces` (branch `main`).
2. **Repositório Público de Releases do APK:** `https://github.com/bellaludocess-maker/bellalu-apk`
   - **Link direto permanente do APK mais recente:**
     `https://github.com/bellaludocess-maker/bellalu-apk/releases/latest/download/BellaLu_Painel_Admin.apk`
   - **Por que existe esse segundo repositório?** O plano gratuito (Spark) do Firebase Hosting proíbe hospedar arquivos executáveis/instaladores (`.apk` / `.exe`). Hospedando o `.apk` nas Releases do GitHub em `bellalu-apk`, o aplicativo Android da dona da loja consegue verificar novas versões via API do GitHub e baixar a atualização diretamente com 1 clique, sem precisar de login.

---

## 4. Decisões Técnicas e Armadilhas Já Resolvidas (Não Regredir!)

1. **Permissão de Internet no Android Release (`AndroidManifest.xml`):**
   - O arquivo [`android/app/src/main/AndroidManifest.xml`](android/app/src/main/AndroidManifest.xml) possui `<uses-permission android:name="android.permission.INTERNET"/>` e `ACCESS_NETWORK_STATE`. Nunca remova essas tags, pois sem elas o APK em modo `--release` bloqueia conexões com o Firebase e Cloudinary.
2. **Prioridade do Firestore Remoto sobre Cache Local:**
   - Em [`firestore_catalog_repository.dart`](lib/modules/external/firebase/firestore_catalog_repository.dart), os documentos vindos do Firestore sempre têm prioridade sobre a lista local, e tanto `main.dart` quanto `main_admin.dart` possuem `WidgetsBindingObserver` que recarrega o catálogo quando o app volta ao foco (`AppLifecycleState.resumed`).
3. **Margem de Segurança Mobile (`SafeArea` Inferior):**
   - Em [`admin_screen.dart`](lib/modules/admin/views/admin_screen.dart), [`admin_login_gate.dart`](lib/modules/admin/views/admin_login_gate.dart) e [`catalog_screen.dart`](lib/modules/catalog/views/catalog_screen.dart), o rodapé com o `SunflowerDeveloperBadge` possui `SafeArea` + espaçamento inferior extra (`MediaQuery.viewPaddingOf(context).bottom + 64`) para nunca ficar encoberto pela barra de navegação de 3 botões do Android.

---

## 5. Passo a Passo Oficial de Testes, Build, APK Release e Deploy

Sempre que o usuário autorizar o deploy e atualização do APK:

### Passo 1 — Rodar os Testes Automatizados
```powershell
flutter test
```

### Passo 2 — Incrementar a Versão do Painel (quando houver atualização do APK)
Em [`lib/core/constants/app_constants.dart`](lib/core/constants/app_constants.dart):
- Incremente `currentAdminBuildNumber` (ex.: de `4` para `5`) e `currentAdminVersionLabel` (ex.: `'2.3.0'`).

### Passo 3 — Compilar Painel Admin Web (`/painel/`) e Vitrine Pública (`/`)
```powershell
flutter build web --release -t lib/main_admin.dart --base-href /painel/ -o build/web_admin
flutter build web --release -t lib/main.dart
New-Item -ItemType Directory -Force -Path build\web\painel | Out-Null
Copy-Item -Path build\web_admin\* -Destination build\web\painel -Recurse -Force
```
Atualize também o arquivo `build\web\painel\version.json` com o mesmo `buildNumber` e `version`:
```json
{
  "version": "2.2.0",
  "buildNumber": 4,
  "apkUrl": "https://github.com/bellaludocess-maker/bellalu-apk/releases/latest/download/BellaLu_Painel_Admin.apk"
}
```
*(Atenção: NUNCA copie o arquivo `.apk` para dentro de `build\web`, pois o Firebase Hosting bloqueia arquivos `.apk` no plano Spark).*

### Passo 4 — Gerar o APK Release e Publicar no GitHub Releases (`bellalu-apk`)
```powershell
flutter build apk --release -t lib/main_admin.dart
Copy-Item -Path build\app\outputs\flutter-apk\app-release.apk -Destination BellaLu_Painel_Admin.apk -Force
powershell -ExecutionPolicy Bypass -File scripts\publish_apk_release.ps1 -BuildNumber 4 -VersionLabel "2.2.0"
```

### Passo 5 — Publicar no Firebase Hosting e Subir Código no GitHub
```powershell
npx firebase-tools deploy --only hosting --project bellaludoces
git add .
git commit -m "feat: descrição da atualização"
git push origin main
```
