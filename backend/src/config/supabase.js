const { createClient } = require('@supabase/supabase-js');
require('dotenv').config();

const supabaseUrl  = process.env.SUPABASE_URL;
const serviceKey   = process.env.SUPABASE_SERVICE_KEY;

if (!supabaseUrl || !serviceKey) {
  throw new Error(
    'SUPABASE_URL dan SUPABASE_SERVICE_KEY wajib ada di .env\n' +
    'Ambil service_role key dari: Supabase Dashboard → Settings → API'
  );
}

/**
 * Client dengan service_role key — melewati semua RLS.
 * HANYA digunakan di backend, JANGAN dikirim ke client/Flutter.
 */
const supabase = createClient(supabaseUrl, serviceKey, {
  auth: {
    autoRefreshToken: false,
    persistSession:   false,
  },
});

module.exports = supabase;
