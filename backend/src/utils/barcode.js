// Generator barcode numerik format EAN-13.
// 12 digit pertama acak, digit ke-13 adalah check digit agar tetap valid
// bila suatu saat dicetak dan dipindai dengan scanner barcode sungguhan.

const ean13CheckDigit = (base12) => {
  let sum = 0;
  for (let i = 0; i < 12; i++) {
    sum += Number(base12[i]) * (i % 2 === 0 ? 1 : 3);
  }
  return String((10 - (sum % 10)) % 10);
};

// Hasilkan satu kandidat barcode numerik 13 digit.
const generateNumericBarcode = () => {
  let base = '';
  for (let i = 0; i < 12; i++) {
    base += Math.floor(Math.random() * 10);
  }
  return base + ean13CheckDigit(base);
};

module.exports = { generateNumericBarcode };
