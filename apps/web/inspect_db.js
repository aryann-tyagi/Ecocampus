const { createClient } = require('@supabase/supabase-js');

const url = 'https://scwssqiocxotgmjgwqjg.supabase.co';
const anonKey = 'sb_publishable_KawBvIvaEdfkRSnMZy6HOQ_P0tClS3n';

const supabase = createClient(url, anonKey);

async function inspect() {
  console.log('--- Inspecting profiles ---');
  const { data: profiles, error: pErr } = await supabase.from('profiles').select('*');
  if (pErr) console.error('Profiles err:', pErr);
  else console.log('Profiles count:', profiles.length, profiles);

  console.log('--- Inspecting eco_point_events ---');
  const { data: events, error: eErr } = await supabase.from('eco_point_events').select('*');
  if (eErr) console.error('Events err:', eErr);
  else console.log('Events count:', events.length, events);

  console.log('--- Testing get_campus_leaderboard RPC ---');
  const { data: lb, error: lErr } = await supabase.rpc('get_campus_leaderboard', { p_limit: 50 });
  if (lErr) console.error('Leaderboard err:', lErr);
  else console.log('Leaderboard count:', lb?.length, lb);
}

inspect().catch(console.error);
