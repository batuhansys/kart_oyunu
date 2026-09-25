// lib/core/constants/cities.dart ile birebir ayni liste. Sunucu, giris
// ucretini/odulu HICBIR ZAMAN client'tan gelen degerle almaz — sadece
// client'tan gelen cityId'yi burada arayip kendi bildigi entryFee'yi
// kullanir. Boylece bir client'in sahte/dusuk bir entryFee gondererek
// hile yapmasi mumkun degildir.
const CITIES = {
  istanbul: { id: 'istanbul', name: 'İstanbul', entryFee: 250 },
  london: { id: 'london', name: 'Londra', entryFee: 1000 },
  rio: { id: 'rio', name: 'Rio', entryFee: 2500 },
  tokyo: { id: 'tokyo', name: 'Tokyo', entryFee: 10000 },
  lasvegas: { id: 'lasvegas', name: 'Las Vegas', entryFee: 50000 },
  maras: { id: 'maras', name: 'Maraş', entryFee: 250000 },
};

function getCity(cityId) {
  return CITIES[cityId] || null;
}

module.exports = { CITIES, getCity };
