/**
 * Cloudflare Worker Oficial - Bella Lu Doces (InfinitePay Checkout + Webhook -> Firebase Firestore)
 *
 * Rotas suportadas:
 * 1. POST /create-checkout -> Cria link oficial na API da InfinitePay ($lucineide-silva-jan) livre de CORS
 *    e injeta automaticamente a URL deste próprio Worker como `webhook_url`.
 * 2. POST /webhook         -> Recebe o aviso automático de pagamento aprovado da InfinitePay
 *    e atualiza o pedido correspondente na coleção `orders` do Firebase Firestore (`bellaludoces`).
 */

const FIREBASE_PROJECT_ID = "bellaludoces";
const INFINITEPAY_HANDLE = "lucineide-silva-jan";
const REDIRECT_URL = "https://www.bellaludoces.com.br/";

const CORS_HEADERS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
  "Access-Control-Allow-Headers": "Content-Type, Authorization",
};

export default {
  async fetch(request) {
    if (request.method === "OPTIONS") {
      return new Response(null, { status: 204, headers: CORS_HEADERS });
    }

    const url = new URL(request.url);
    const workerOrigin = url.origin;

    // 1. Rota para criar o Link de Checkout na InfinitePay (chamada pelo site da Bella Lu)
    if (request.method === "POST" && url.pathname.endsWith("/create-checkout")) {
      try {
        const body = await request.json();
        const orderNsu = (body.order_nsu || `ped-${Date.now()}`).toString();
        const items = Array.isArray(body.items) ? body.items : [];

        const infinitePayPayload = {
          handle: body.handle || INFINITEPAY_HANDLE,
          order_nsu: orderNsu,
          redirect_url: body.redirect_url || REDIRECT_URL,
          webhook_url: `${workerOrigin}/webhook`,
          items: items.map((item) => ({
            quantity: Number(item.quantity || 1),
            price: Number(item.price || 0),
            description: String(item.description || item.name || "Produto Bella Lu"),
          })),
        };

        if (body.customer) {
          infinitePayPayload.customer = body.customer;
        }

        const response = await fetch(
          "https://api.infinitepay.io/invoices/public/checkout/links",
          {
            method: "POST",
            headers: { "Content-Type": "application/json" },
            body: JSON.stringify(infinitePayPayload),
          }
        );

        const data = await response.json();
        return new Response(JSON.stringify(data), {
          status: response.status,
          headers: { ...CORS_HEADERS, "Content-Type": "application/json" },
        });
      } catch (err) {
        return new Response(
          JSON.stringify({ error: err.message || "Erro ao criar checkout InfinitePay" }),
          {
            status: 500,
            headers: { ...CORS_HEADERS, "Content-Type": "application/json" },
          }
        );
      }
    }

    // 2. Rota de Webhook (chamada automaticamente pela InfinitePay quando o cliente paga)
    if (request.method === "POST" && (url.pathname.endsWith("/webhook") || url.pathname === "/")) {
      try {
        const payload = await request.json();
        const orderNsu = (payload.order_nsu || "").toString().trim();
        const receiptUrl = (payload.receipt_url || "").toString().trim();
        const captureMethod = (payload.capture_method || "infinitepay").toString().trim();
        const transactionNsu = (payload.transaction_nsu || payload.invoice_slug || "").toString().trim();

        if (!orderNsu) {
          return new Response(
            JSON.stringify({ received: true, warning: "Sem order_nsu" }),
            {
              status: 200,
              headers: { ...CORS_HEADERS, "Content-Type": "application/json" },
            }
          );
        }

        // Atualiza o documento do pedido no Firebase Firestore (`orders/{orderNsu}`)
        const firestoreUrl =
          `https://firestore.googleapis.com/v1/projects/${FIREBASE_PROJECT_ID}/databases/(default)/documents/orders/${encodeURIComponent(orderNsu)}` +
          `?updateMask.fieldPaths=isCompleted&updateMask.fieldPaths=paymentStatus&updateMask.fieldPaths=receiptUrl&updateMask.fieldPaths=captureMethod&updateMask.fieldPaths=transactionNsu`;

        const firestorePatch = {
          fields: {
            isCompleted: { booleanValue: true },
            paymentStatus: { stringValue: "paid" },
            receiptUrl: { stringValue: receiptUrl },
            captureMethod: { stringValue: captureMethod },
            transactionNsu: { stringValue: transactionNsu },
          },
        };

        await fetch(firestoreUrl, {
          method: "PATCH",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify(firestorePatch),
        });

        return new Response(
          JSON.stringify({ success: true, order_nsu: orderNsu, status: "paid" }),
          {
            status: 200,
            headers: { ...CORS_HEADERS, "Content-Type": "application/json" },
          }
        );
      } catch (err) {
        return new Response(
          JSON.stringify({ error: err.message || "Erro ao processar webhook" }),
          {
            status: 400,
            headers: { ...CORS_HEADERS, "Content-Type": "application/json" },
          }
        );
      }
    }

    return new Response(
      JSON.stringify({
        service: "Bella Lu Doces - InfinitePay Webhook & Checkout Worker",
        status: "online",
      }),
      {
        status: 200,
        headers: { ...CORS_HEADERS, "Content-Type": "application/json" },
      }
    );
  },
};
