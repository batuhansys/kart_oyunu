const { SUITS, RANKS } = require('./constants');

function isBluffCard(rank) {
  return rank === 2 || rank === 14; // 2 ve A: blof kartlari
}

function randomCard() {
  const suit = SUITS[Math.floor(Math.random() * SUITS.length)];
  const rank = RANKS[Math.floor(Math.random() * RANKS.length)];
  return { suit, rank };
}

module.exports = { isBluffCard, randomCard };
