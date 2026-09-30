// Encoder EAN-13 murni (tanpa dependency).
// Mengubah 13 digit barcode menjadi pola 95 modul ('1' = bar hitam, '0' = spasi).
// Dipakai untuk menampilkan preview barcode di command prompt.
//
// Karena keluarannya hanya ditentukan oleh digit barcode, angka yang sama
// selalu menghasilkan pola yang sama (permanen).

const L = {
  0: '0001101',
  1: '0011001',
  2: '0010011',
  3: '0111101',
  4: '0100011',
  5: '0110001',
  6: '0101111',
  7: '0111011',
  8: '0110111',
  9: '0001011',
};

const G = {
  0: '0100111',
  1: '0110011',
  2: '0011011',
  3: '0100001',
  4: '0011101',
  5: '0111001',
  6: '0000101',
  7: '0010001',
  8: '0001001',
  9: '0010111',
};

const R = {
  0: '1110010',
  1: '1100110',
  2: '1101100',
  3: '1000010',
  4: '1011100',
  5: '1001110',
  6: '1010000',
  7: '1000100',
  8: '1001000',
  9: '1110100',
};

// Pola parity untuk 6 digit kiri, ditentukan oleh digit pertama.
const PARITY = {
  0: 'LLLLLL',
  1: 'LLGLGG',
  2: 'LLGGLG',
  3: 'LLGGGL',
  4: 'LGLLGG',
  5: 'LGGLLG',
  6: 'LGGGLL',
  7: 'LGLGLG',
  8: 'LGLGGL',
  9: 'LGGLGL',
};

const isValidEan13 = (digits) => {
  if (!/^\d{13}$/.test(String(digits || ''))) return false;
  let sum = 0;
  for (let i = 0; i < 12; i++) {
    sum += Number(digits[i]) * (i % 2 === 0 ? 1 : 3);
  }
  return (10 - (sum % 10)) % 10 === Number(digits[12]);
};

// Kembalikan string 95 karakter '0'/'1'.
const ean13Modules = (digits) => {
  const code = String(digits || '');
  if (!/^\d{13}$/.test(code)) {
    throw new Error('Barcode harus berupa 13 digit angka');
  }

  const parity = PARITY[Number(code[0])];

  let bits = '101'; // start guard
  for (let i = 1; i <= 6; i++) {
    const digit = Number(code[i]);
    bits += parity[i - 1] === 'L' ? L[digit] : G[digit];
  }
  bits += '01010'; // center guard
  for (let i = 7; i <= 12; i++) {
    bits += R[Number(code[i])];
  }
  bits += '101'; // end guard

  return bits;
};

module.exports = { ean13Modules, isValidEan13 };
