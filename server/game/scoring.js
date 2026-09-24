// lib/state/game/scoring_service.dart dosyasinin JS'e birebir portu.
// Kurallar:
// - Pas gecen oyuncu o elden puan almaz/kaybetmez.
// - 2 ve A blof kartlaridir: bu karti elinde tutan oyuncu icin sonuc
//   HER ZAMAN puansizdir, tipki pas gecilmis gibi.
// - Riske giren oyuncu karti rakibinden yuksekse kazanc, esit/dusukse
//   ceza puani alir.
// - Cifte Riske Gir: kazanc/kayip puani 2 ile carpilir.
// - Zaman asimi (timeout): kazanan kart olsa dahi puan getirmez;
//   kaybeden kartsa ciftte riskin ceza puanini alir.
const { SCORE_TABLE } = require('./constants');
const { isBluffCard } = require('./cards');

function scoreForPlayer({ ownCard, opponentCard, choice }) {
  if (choice === 'pass') return 0;
  if (isBluffCard(ownCard.rank)) return 0;

  const entry = SCORE_TABLE[ownCard.rank];
  const won = ownCard.rank > opponentCard.rank;

  if (choice === 'timeout') {
    return won ? 0 : entry.lose * 2;
  }

  const base = won ? entry.win : entry.lose;
  const multiplier = choice === 'doubleRisk' ? 2 : 1;
  return base * multiplier;
}

function calculateRound({ cardA, choiceA, cardB, choiceB }) {
  const deltaA = scoreForPlayer({ ownCard: cardA, opponentCard: cardB, choice: choiceA });
  const deltaB = scoreForPlayer({ ownCard: cardB, opponentCard: cardA, choice: choiceB });
  return { deltaA, deltaB };
}

module.exports = { calculateRound };
