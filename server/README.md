# RİSK Get and Gain — Çok Oyunculu Sunucu

Bu klasör, Flutter uygulamasındaki **çevrimiçi (multiplayer) modun**
arka planında çalışan Node.js sunucusudur. İki gerçek oyuncuyu
eşleştirir, kartları dağıtır, 7 saniyelik karar süresini sayar ve
puanlamayı hesaplar. Bunu bilerek **istemci (telefon/tarayıcı) tarafına
bırakmadık**: eğer puanlama telefonda hesaplansaydı, biri uygulamayı
değiştirip kendine sürekli kazandırabilirdi. Sunucu buna izin vermez —
oyuncular sadece "riske gir/pas geç" gibi niyetlerini bildirir, kararı
her zaman sunucu verir.

Kurallar `lib/state/game/` altındaki tek-oyunculu koddan birebir
kopyalanmıştır (puan tablosu, blöf kartları, çifte risk, 250/-250
eşiği, art arda pas sınırı). Kuralları değiştirirseniz **iki tarafı da**
güncellemeniz gerekir: `lib/core/constants/score_table.dart` ve
`server/game/constants.js`.

## Klasör yapısı

```
server/
  server.js            Giris noktasi: Express + Socket.IO kurulumu
  game/
    constants.js       Puan tablosu, esikler, sureler (Dart tarafiyla ayni)
    cards.js            Kart uretimi, blof karti kontrolu
    scoring.js           Puanlama mantigi (ScoringService'in JS portu)
    room.js              Tek bir eslesmenin state machine'i (2 oyuncu)
    roomManager.js       Tum odalari, kodlari ve "hizli eslesme" kuyrugunu yonetir
```

## 1) Bilgisayarınızda deneme (deploy etmeden önce)

Node.js kurulu olması yeterli (18 veya üstü).

```bash
cd server
npm install
npm start
```

`Sunucu 3000 portunda calisiyor.` yazısını görürseniz sunucu ayakta
demektir. Tarayıcıdan `http://localhost:3000` adresine girip "RISK Get
and Gain multiplayer sunucusu calisiyor." yazısını görerek de
doğrulayabilirsiniz.

Flutter uygulamasını **aynı bilgisayarda** çalıştırıyorsanız (Android
emülatörü, Windows/masaüstü veya tarayıcı) hiçbir ayar yapmanıza gerek
yok, varsayılan adresler zaten doğru şekilde ayarlı.

### Gerçek bir telefondan aynı Wi-Fi üzerinden test etmek isterseniz

1. Bilgisayarınızın yerel ağ IP adresini bulun:
   - Windows: PowerShell'de `ipconfig` yazın, "IPv4 Address" satırına bakın (örn. `192.168.1.34`).
2. Telefon ve bilgisayarın **aynı Wi-Fi ağında** olduğundan emin olun.
3. Uygulamada Çevrimiçi Oyna ekranındaki "Gelişmiş: Sunucu Adresi"
   bölümüne `http://192.168.1.34:3000` yazıp "Bağlan"a basın.
4. Windows Güvenlik Duvarı ilk seferinde izin isteyebilir, izin verin.

## 2) Ücretsiz olarak internete açma (Render.com)

Sıfır deneyimle en kolay yol budur: kod GitHub'da durur, Render onu
otomatik olarak derleyip 7/24 (ücretsiz katmanda: kullanılmadığında
uyuyarak) çalıştırır ve size `https://sizin-servisiniz.onrender.com`
gibi bir adres verir.

**Adımlar:**

1. **GitHub hesabınız yoksa** [github.com](https://github.com) üzerinden ücretsiz bir hesap açın.
2. Bu proje klasörünü (tamamını, sadece `server/` değil) bir GitHub
   deposuna (repository) push edin. Terminalde proje kök dizininde:
   ```bash
   git init
   git add .
   git commit -m "İlk kayıt"
   ```
   Ardından GitHub'da yeni bir boş repo oluşturup ekranda size verdiği
   `git remote add origin ...` ve `git push` komutlarını çalıştırın.
3. [render.com](https://render.com) adresine gidip **GitHub hesabınızla**
   giriş yapın (kredi kartı istemez, ücretsiz katman için gerekmez).
4. "New +" → **"Web Service"** seçin, az önce push ettiğiniz repoyu seçin.
5. Render size ayarları sorduğunda:
   - **Root Directory:** `server`
   - **Runtime:** `Node`
   - **Build Command:** `npm install`
   - **Start Command:** `node server.js`
   - **Instance Type:** `Free`
6. "Create Web Service" deyip bekleyin (ilk kurulum 1-2 dakika sürer).
   Loglarda `Sunucu XXXX portunda calisiyor.` yazısını görünce hazırdır.
7. Sayfanın üstünde size verilen adresi kopyalayın, örn.
   `https://risk-multiplayer-server.onrender.com`.
8. Flutter uygulamasında Çevrimiçi Oyna ekranındaki "Gelişmiş: Sunucu
   Adresi" alanına bu adresi yazıp "Bağlan"a basın. Kalıcı olsun
   isterseniz `lib/core/network/socket_service.dart` içindeki
   `productionUrl` değerini bu adresle güncelleyip `defaultLocalUrl`
   yerine bunu varsayılan yapabilirsiniz.

**Not — ücretsiz katmanın tek dezavantajı:** 15 dakika kimse
kullanmazsa sunucu "uyur"; bir sonraki bağlantı isteği onu tekrar
uyandırır ama bu ilk istek ~20-50 saniye sürebilir (kullanıcıya
"bağlanılıyor..." olarak görünür, hata değildir). Oyununuz gerçek
kullanıcılara açılıp bu gecikme sorun olursa, Render'ın ücretli
"Starter" planına ($7/ay civarı, sunucu hiç uyumaz) geçebilirsiniz;
kod tarafında hiçbir değişiklik gerekmez.

## 3) Sunucu kodunu değiştirdiğinizde

Render, GitHub'a her `git push` yaptığınızda otomatik olarak yeniden
deploy eder. Yerelde test edip çalıştığından emin olduktan sonra push
etmeniz yeterlidir.

## Bilinen sınırlamalar (MVP kapsamı)

- **Yeniden bağlanma yok:** Bir oyuncunun bağlantısı koparsa (uygulama
  kapanır, internet gider) rakip hemen otomatik kazanır; kopan oyuncu
  aynı maça geri dönemez. İleride eklenebilir ama karmaşıklığı
  artırdığı için ilk sürümde bilinçli olarak dışarıda bırakıldı.
- **Oda/eşleşme bilgisi bellekte tutulur:** Sunucu yeniden başlatılırsa
  (deploy, çökme) o an devam eden tüm maçlar kaybolur. Küçük ölçek için
  sorun değildir; büyürse Redis gibi bir kalıcı depoya taşınabilir.
- **RC ödülü yok:** Çevrimiçi modda kazanınca tek-oyunculu moddaki gibi
  RC (oyun içi para) verilmiyor; bu bilinçli bir kapsam kararıdır,
  isterseniz kolayca eklenebilir (game_over olayına bir ödül alanı
  eklemek yeterli).
