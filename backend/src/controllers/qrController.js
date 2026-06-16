const supabase = require('../config/supabase');
const logger = require('../config/logger');
const { encrypt } = require('../utils/crypto');
const { successResponse, errorResponse } = require('../utils/response');
const crypto = require('crypto');
const { DateTime } = require('luxon');

const generateQR = async (req, res) => {
  const token_unik  = crypto.randomBytes(16).toString('hex');
  const expired_at  = DateTime.now().plus({ seconds: 30 }).toJSDate();
  const lat = parseFloat(req.tenantSettings.office_lat);
  const lng = parseFloat(req.tenantSettings.office_lng);

  const payload = JSON.stringify({
    token_unik,
    lat,
    lng,
    expired_at: expired_at.getTime(),
  });

  const encrypted = encrypt(payload);

  try {
    const { error } = await supabase.from('qr_sessions').insert({
      token_unik,
      payload_encrypted: encrypted,
      lokasi_lat:        lat,
      lokasi_lng:        lng,
      berlaku_hingga:    expired_at,
      id_tenant:         req.tenantId,
    });

    if (error) throw error;

    return successResponse(res, 'QR Generated', {
      qr_data:          encrypted,
      expired_at,
      expired_in_seconds: 30,
    });
  } catch (err) {
    logger.error('[generateQR]', err);
    return errorResponse(res, 'Gagal generate QR');
  }
};

const getStatus = async (req, res) => {
  try {
    const { data, error } = await supabase
      .from('qr_sessions')
      .select('*')
      .gt('berlaku_hingga', new Date().toISOString())
      .eq('sudah_dipakai', false)
      .eq('id_tenant', req.tenantId)
      .order('created_at', { ascending: false })
      .limit(1)
      .maybeSingle();

    if (error) throw error;
    return successResponse(res, 'QR Status', data || null);
  } catch (err) {
    return errorResponse(res, 'Gagal ambil status QR');
  }
};

module.exports = { generateQR, getStatus };
