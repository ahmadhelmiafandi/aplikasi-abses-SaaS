const CryptoJS = require('crypto-js');
require('dotenv').config();

const SECRET_KEY = process.env.QR_SECRET_KEY;
if (!SECRET_KEY) throw new Error('QR_SECRET_KEY environment variable is not set');

const encrypt = (text) => {
  return CryptoJS.AES.encrypt(text, SECRET_KEY).toString();
};

const decrypt = (ciphertext) => {
  const bytes = CryptoJS.AES.decrypt(ciphertext, SECRET_KEY);
  return bytes.toString(CryptoJS.enc.Utf8);
};

module.exports = { encrypt, decrypt };
