# RİSK Get and Gain — Flutter Projesi (Professional Edition)

Bu, "RİSK Get and Gain" mobil kart oyununun **profesyonel mimari ve
görsel cilaya sahip** Flutter implementasyonudur. Android Studio'da
açıp `flutter pub get` sonrası doğrudan çalıştırabilirsiniz.

Bu sürüm, önceki (temel) sürüme göre şu iki eksende tamamen
yenilenmiştir:

## 1) Mimari yenileme

- **State management: Riverpod'a geçildi** (`flutter_riverpod`).
  `ChangeNotifier` tabanlı basit `AppSession` sınıfı kaldırıldı;
  yerine değişmez (immutable) state sınıfları + `StateNotifier`
  kullanan `AuthNotifier`, `WalletNotifier`, `GameNotifier` geldi.
  Widget'lar artık `ConsumerWidget`/`ConsumerStatefulWidget` ile
  `ref.watch`/`ref.read` kullanıyor.
- **Repository pattern:** `domain/repositories/` altında soyut
  arayüzler (`AuthRepository`, `EconomyRepository`), `data/repositories/`
  altında bunların yerel (backend'siz) implementasyonları
  (`LocalAuthRepository`, `LocalEconomyRepository`). Gerçek bir
  backend'e geçerken tek yapmanız gereken, ilgili Riverpod
  provider'ında (`authRepositoryProvider`, `economyRepositoryProvider`)
  bu sınıfın yerine yenisini bağlamak — çağıran hiçbir kodun
  değişmesine gerek yok.
- **Katmanlı (clean architecture'a yakın) klasör yapısı:**
  `domain/` (entity'ler, repository arayüzleri — hiçbir dış bağımlılığı
  yok), `data/` (repository implementasyonları, servisler), `state/`
  (Riverpod notifier'ları), `features/` (ekranlar/UI), `core/` (tema,
  sabitler, router, ortak widget'lar, yardımcılar).
- **Result tipi ile hata yönetimi:** `core/utils/result.dart` içinde
  bağımlılıksız bir `Result<T>` (Success/Failure) sealed class'ı.
  Repository'ler exception fırlatmak yerine bu tipi döner; UI,
  `result.when(success: ..., failure: ...)` ile açık şekilde her iki
  durumu da ele alır.
- **Merkezi loglama:** `core/utils/logger.dart` — `print` çağrıları
  kod içine dağılmak yerine tek bir `AppLogger` üzerinden geçer,
  ileride Sentry/Crashlytics gibi bir servise kolayca bağlanabilir.
- **Oyun motoru artık tamamen değişmez (immutable) state kullanıyor:**
  `GameState` her değişiklikte yeni bir kopya olarak üretilir,
  `GameNotifier` (StateNotifier) bu üretimi yönetir. `roundId` sayacı
  sayesinde UI, "yeni el başladı mı" sorusunu kart nesnelerini
  karşılaştırmak gibi kırılgan bir yönteme değil, güvenilir bir
  sayaca dayandırıyor.
- **`dispose` sonrası güvenlik:** `GameNotifier` kendi `_disposed`
  bayrağını tutar; ekran kapandıktan sonra gecikmeli bir
  `Future.delayed` callback'i tetiklense bile state güncellemesi
  denenmez, çökme riski oluşmaz.
- **Genişletilmiş test kapsamı:** `test/` altında artık puanlama
  servisi, kullanıcı ID üretici, `GameNotifier` (state machine) ve
  `LocalAuthRepository` için testler var (5 dosya, ~35 test).
  `GameNotifier` testleri bilinçli olarak tek-el senaryolarla
  sınırlandı; çok-elli senaryoların neden şimdilik test edilmediği
  (gerçek rastgelelik + zaman gecikmesi kombinasyonunun testleri
  "flaky" yapma riski) test dosyasında yorum olarak açıklandı —
  dürüst ve şeffaf bir mühendislik kararı.
- **`analysis_options.yaml`** eklendi (flutter_lints + ek kurallar)
  — kod kalitesi kontrolü artık projenin bir parçası.

## 2) Görsel ve deneyim (UX) yenileme

- **Google Fonts entegrasyonu:** başlıklarda casino/premium hissi
  veren "Cinzel" gösterişli yazı tipi, gövde metninde "Inter".
- **Vektörel çizilmiş iskambil kartları:** dış görsel dosyasına
  ihtiyaç duymadan, `Stack`/`Text` ile çizilen temiz kart ön yüzü
  (köşelerde rank+suit, ortada büyük sembol) ve `CustomPaint` ile
  çizilen, baklava desenli, altın kenarlıklı casino tarzı kart arkası.
- **3D kart çevirme animasyonu:** `Matrix4.rotateY` ile kartın
  kapalıdan açığa gerçekçi bir çevirme animasyonuyla geçmesi
  (`FlippableCard`).
- **Akıcı zamanlayıcı halkası:** önceki sürümdeki elle nokta-nokta
  hesaplanan çerçeve, Flutter'ın `PathMetrics.extractPath` API'siyle
  yeniden yazıldı — çok daha pürüzsüz, matematiksel olarak doğru ve
  bakımı kolay.
- **Dokunsal geri bildirim + "basılma" animasyonu:** `PressableScale`
  adlı yeniden kullanılabilir bir wrapper, tüm ana butonlarda
  (menü, tercih butonları, mağaza kartları vb.) hafif haptic feedback
  ve ölçek animasyonu sağlıyor — standart `ElevatedButton`'a göre çok
  daha "premium" bir his veriyor.
- **Kazanma anında konfeti:** `confetti` paketiyle, oyunu kazanınca
  ekranda patlayan konfeti efekti.
- **Ses altyapısı hazır:** `SoundService` arayüzü + `audioplayers`
  tabanlı implementasyon; tıklama, kart çevirme, kazanma/kaybetme,
  RC kazanma anlarında çağrılıyor. **Gerçek ses dosyaları projede
  yok** (bkz. aşağıdaki "Eklenmesi gerekenler" bölümü) — dosya
  bulunamadığında hata sessizce loglanır, uygulama çökmez.
- **Sayfa geçişleri:** tüm route'lar artık `go_router`'ın
  `CustomTransitionPage`'i ile yumuşak bir soluklaşma+kayma
  animasyonuyla geçiyor.
- **Animasyonlu RC sayacı:** bakiye değiştiğinde (`AnimatedRcCounter`)
  eski değerden yeniye doğru sayarak geçiş yapıyor.
- **Animasyonlu splash ekranı:** logo elastik bir ölçeklenme +
  soluklaşma animasyonuyla açılıyor.
- **Gradyan arka planlar:** düz renk yerine, tüm ekranlarda tutarlı
  koyu yeşil/lacivert degrade (`GradientBackground`).

## ÖNEMLİ: Bu kod nasıl üretildi, nelere dikkat edin

Bu kod bir AI asistanı (Claude) tarafından, gerçek bir Flutter SDK /
emülatör erişimi OLMADAN yazılmıştır:
- Kod hiç derlenmedi, hiç çalıştırılmadı, `flutter analyze` veya
  `flutter test` ile doğrulanmadı.
- Süslü parantez dengesi ve import/isim tutarlılığı (eski sınıf
  isimlerinin kalıp kalmadığı, `provider` paketi kalıntısı olup
  olmadığı vb.) otomatik script'lerle kontrol edildi, ancak küçük
  sözdizimi/tip hataları olması olasıdır.
- **İlk yapmanız gereken:**
  ```
  flutter pub get
  flutter analyze
  flutter test
  flutter run
  ```
  `flutter analyze` çıktısında hata varsa (muhtemelen küçük, örn. bir
  import yolu ya da parametre adı), bunlar kolayca düzeltilebilir
  düzeydedir — mimari tasarım ve iş mantığı elle dikkatlice
  doğrulanmıştır.

## Eklenmesi gerekenler (projeye dahil edilemedi)

- **Ses dosyaları:** `assets/sounds/click.mp3`, `card_flip.mp3`,
  `win.mp3`, `lose.mp3`, `coin.mp3` — bu dosyaları ekleyip
  `pubspec.yaml`'daki `assets:` bölümünü açın. `SoundService` arayüzü
  ve çağrı noktaları zaten hazır.
- **Gerçek backend/Firebase:** `LocalAuthRepository` ve
  `LocalEconomyRepository` yerine gerçek implementasyonlar yazıp
  ilgili Riverpod provider'larına bağlayın.
- **Google Play Billing:** `in_app_purchase` paketiyle gerçek satın
  alma akışı; `LocalEconomyRepository.purchasePackage` bu akışı
  simüle ediyor.
- **Arkadaşlar / Atölye / Günlük Çark / Royal Pass:** ekranlar
  görsel olarak hazır ve gezilebilir, ancak arkasındaki veri kalıcı
  değil (kod içinde `TODO:` yorumlarıyla işaretli).

## Netleştirilmesi gereken oyun kuralları (varsayılan seçilenler)

Kaynak dokümanda birbiriyle çelişen iki taslak vardı. Aşağıdaki
varsayımlar yapıldı; değiştirmek isterseniz belirtilen tek dosyayı
güncellemeniz yeterli:

| Konu | Seçilen değer | Dosya |
|---|---|---|
| Şehir listesi | 6 şehir (İstanbul...Maraş) | `lib/core/constants/cities.dart` |
| Puan tablosu | v2 (K/Q/J: 40/-100...) | `lib/core/constants/score_table.dart` |
| Mağaza paketleri | Fiyatsız RC listesi | `lib/features/shop/shop_screen.dart` |
| Sonuç ekranı süresi | 3 saniye | `lib/core/constants/game_constants.dart` |

## Proje yapısı

```
lib/
  core/                sabitler, tema (Google Fonts), router, ortak widget'lar, Result/Logger
  domain/
    entities/          PlayingCard, GameCity, UserProfile, PlayerChoice, GameHistoryEntry
    repositories/      AuthRepository, EconomyRepository (soyut arayüzler)
  data/
    repositories/      Local* implementasyonları
    services/          UserIdGenerator, SoundService
  state/
    auth_provider.dart, wallet_provider.dart, sound_provider.dart
    game/              <-- OYUN MOTORU: GameState, GameNotifier, ScoringService, AiDecisionService
  features/            tüm ekranlar (UI)
test/                  5 test dosyası (~35 test)
```

## Çok oyunculu (multiplayer) mod

Uygulamaya gerçek zamanlı çok oyunculu bir mod eklendi: ana ekrandaki
**"Çevrimiçi Oyna"** kartından girilir. İki seçenek sunar:

- **Hızlı Eşleşme:** Kuyrukta bekleyen rastgele bir rakiple eşleştirir.
- **Oda Kur / Odaya Katıl:** 5 karakterlik bir kod üretir, bu kodu bir
  arkadaşınıza gönderip aynı odada oynayabilirsiniz.

Puanlama, kart dağıtımı ve 7 saniyelik karar süresi **sunucu
tarafında** hesaplanır (bkz. `server/`) — tek-oyunculu moddaki
kurallarla birebir aynıdır, sadece rakip artık yapay zeka değil gerçek
bir insan. İstemci tarafında hile yapılamaz çünkü skoru her zaman
sunucu belirler.

Sunucuyu nasıl çalıştıracağınız, bilgisayarınızda nasıl test
edeceğiniz ve internete (Render.com üzerinden ücretsiz) nasıl
yayınlayacağınız için **[server/README.md](server/README.md)**
dosyasına bakın — sıfır sunucu/hosting deneyimi varsayılarak adım
adım yazılmıştır.

## Bir sonraki adımlar (öneri sırası)

1. `flutter pub get` + `flutter analyze` ile derleme hatalarını giderin.
2. `flutter test` ile testlerin geçtiğini doğrulayın.
3. Gerçek cihaz/emülatörde oynayıp animasyonların (kart çevirme,
   zamanlayıcı halkası, konfeti) beklediğiniz gibi çalıştığını görsel
   olarak doğrulayın.
4. Ses dosyalarını ekleyin.
5. "Netleştirilmesi gereken oyun kuralları" tablosunu ürün sahibiyle
   teyit edin.
6. Backend/Firebase entegrasyonuna başlayın.
7. Google Play Billing entegrasyonu.
