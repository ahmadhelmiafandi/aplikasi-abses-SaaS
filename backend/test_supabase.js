const { createClient } = require('@supabase/supabase-js');

const supabaseUrl = 'https://ppdutshsvguxgtyclaxj.supabase.co';
const supabaseServiceKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InBwZHV0c2hzdmd1eGd0eWNsYXhqIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc4MDkzMjc0MiwiZXhwIjoyMDk2NTA4NzQyfQ.BD0Jys6hn37vGDVCu-MSpL3qLClq209hkyS4dC2X1ao';
const supabase = createClient(supabaseUrl, supabaseServiceKey, {
  auth: {
    autoRefreshToken: false,
    persistSession: false
  }
});

async function testAdminCreate() {
  console.log('Testing admin.createUser...');
  const email = `test_admin_${Date.now()}@interia.com`;
  const password = 'Password123!';
  try {
    const { data, error } = await supabase.auth.admin.createUser({
      email,
      password,
      email_confirm: true,
      user_metadata: { nama: 'Test Admin Create' }
    });
    if (error) {
      console.error('Admin Create error:', error);
    } else {
      console.log('Admin Create success:', data);
      
      const userId = data.user.id;
      
      console.log('Testing profile insertion...');
      const { error: profileError } = await supabase.from('profiles').insert({
        id: userId,
        nama: 'Test Admin Create',
        email: email,
        role: 'karyawan',
        status_aktif: false,
      });
      
      if (profileError) {
        console.error('Profile insertion error:', profileError);
      } else {
        console.log('Profile insertion success!');
        // Clean up profile
        await supabase.from('profiles').delete().eq('id', userId);
      }

      // Let's delete the created user so we don't pollute the database
      const { error: delErr } = await supabase.auth.admin.deleteUser(userId);
      if (delErr) {
        console.error('Failed to clean up user:', delErr);
      } else {
        console.log('Cleaned up user successfully.');
      }
    }
  } catch (err) {
    console.error('Exception:', err);
  }
}

testAdminCreate();
