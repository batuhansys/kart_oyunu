# 101 Okey (Flutter + Node.js)

Çevrimiçi 101 Okey: 4 koltuklu masa, gerçek oyuncular + botlar, şehir giriş
ücretleri, günlük çark, atölye (parça/sandık/güçler), seviye/XP, arkadaşlar.

## Mimari

- **İstemci:** Flutter + Riverpod + go_router (`lib/`). Yatay ekran.
- **Sunucu:** Node.js + Express + Socket.IO + `firebase-admin` (`server/`).
  Oyunun tüm kuralları ve ekonomi **sunucuda** (otoriter); istemci sadece gösterir.
- **Backend:** Firebase Auth (kullanıcı adı → `{ad}@kartoyunu.app`) + Cloud Firestore.
  `users/{uid}` dokümanı istemciden **yazılamaz** (bkz. `firestore.rules`); bakiye,
  XP, parça, güç vb. sadece sunucu yazar.

### 101 Okey motoru (`server/okey/`)

| Dosya | Görev |
|---|---|
| `tiles.js` | 106 taş, gösterge/okey, sahte okey |
| `melds.js` | Per analizi (seri/grup/çift, joker, 12-13-1), en iyi dizilim çözücü |
| `game.js` | Oyun durumu: dağıtım, çek/aç/işle/okey değiştir/at, puanlama, güçler |
| `bot.js` | Bot yapay zekâsı |
| `room.js` | 4 koltuk, zamanlayıcılar, ekonomi, bot devralma |

Kurallar: 101 puan ya da 5 çift ile el açma, yerden taş alan açmak zorunda,
açılan perlere taş işleme, okey değiştirme, okey ile bitirme / çift ile
bitirme çarpanları, el sonu puanları (kazanan −101, açmayan +202, açanlar
kalan taş toplamı), 3 elde en düşük toplam kazanır.

Ekonomi: şehir giriş ücreti (F) insan oyunculardan alınır; masada 1. → 2.4F,
2. → F iade. XP/şehir parçası sadece şehir kuyruğu maçlarında. Masadan kalkan
ücretini kaybeder, yerine bot oturur.

Güçler (Atölye'den): **ZORBA** sıradakinin turunu atlatır, **KALKAN** el cezasını
yarıya indirir, **KAHİN** destenin üstündeki taşı gösterir.

## Çalıştırma

```bash
# Sunucu (yerel): server/serviceAccountKey.json gerekir (commit edilmez)
cd server && npm install && npm start      # :3000

# İstemci
flutter pub get
flutter run                                # varsayılan: production sunucusu
```

Yerelde test için `lib/state/multiplayer/server_url_provider.dart` içinde
`SocketService.defaultLocalUrl` kullanın (commit etmeyin).

## Testler

```bash
cd server && npm test      # Okey kural motoru birim testleri + bot simülasyonu
flutter test               # Widget/yerel testler (Okey masası farklı ekran boyutlarında)
```

`server/test/rig_server.js`: yalnızca elle test için, insan oyuncuya 102 puanlık
açılış eli veren sunucu sarmalayıcı.

## Dağıtım (Render)

Sunucu Render'da çalışır; `FIREBASE_SERVICE_ACCOUNT` ortam değişkeni
(servis hesabı JSON'unun tek satırı) **zorunludur**. Eksikse oyuncular
"Kimlik doğrulanamadı" hatası alır. Kontrol: `GET /api/health` →
`firebase.ok` true olmalı.
