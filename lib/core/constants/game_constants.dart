/// Oyun kazanma/kaybetme eşikleri.
const int kWinScoreThreshold = 250;
const int kLoseScoreThreshold = -250;

/// Art arda en fazla kaç kez pas geçilebilir (3. elde zorunlu risk kuralı).
const int kMaxConsecutivePasses = 2;

/// Karar süresi (saniye).
const int kDecisionSeconds = 7;

/// Sonuç ekranının ekranda sabit kaldığı süre (saniye).
/// NOT: kaynakta 3 ile 4 saniye arasında çelişki vardı, 3 sn esas alındı.
const int kResultDisplaySeconds = 3;
