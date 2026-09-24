import '../../domain/entities/game_city.dart';

/// NOT: Kaynak dokümanda 5 şehirli ve 6 şehirli iki farklı liste
/// vardı. Burada 6 şehirli (daha kapsamlı) taslak esas alınmıştır.
///
/// Alternatif (v1) liste referans için:
///   Lefkoşya (250 RC), Londra (1.000 RC), Monte Carlo (5.000 RC),
///   Las Vegas (20.000 RC), Maraş (100.000 RC)
const List<GameCity> kCities = [
  GameCity(id: 'istanbul', name: 'İstanbul', entryFee: 250),
  GameCity(id: 'london', name: 'Londra', entryFee: 1000),
  GameCity(id: 'rio', name: 'Rio', entryFee: 2500),
  GameCity(id: 'tokyo', name: 'Tokyo', entryFee: 10000),
  GameCity(id: 'lasvegas', name: 'Las Vegas', entryFee: 50000),
  GameCity(id: 'maras', name: 'Maraş', entryFee: 250000),
];
