// lib/features/shop/shop_screen.dart'taki paket listesiyle birebir ayni.
// Sunucu, /api/shop/purchase istegindeki `amount` degerini burada arar -
// listede olmayan bir miktar asla kabul edilmez (client'in keyfi bir
// miktar gondererek hile yapmasi mumkun degildir). Gercek odeme (Google
// Play Billing vb.) sonradan baglanacak; simdilik her paket dogrudan
// onaylanip RC hesaba geciriliyor.
const SHOP_PACKAGES = [
  { amount: 1000, name: 'Başlangıç Kesesi' },
  { amount: 5000, name: 'Gümüş Kese' },
  { amount: 25000, name: 'Altın Kese' },
  { amount: 100000, name: 'Elmas Sandık' },
  { amount: 500000, name: 'İmparatorluk Hazinesi' },
  { amount: 2500000, name: 'Kraliyet Hazinesi' },
];

module.exports = { SHOP_PACKAGES };
