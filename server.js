const express = require('express');
const path = require('path');

const app = express();
const PORT = process.env.PORT || 3000;
const HOST = '0.0.0.0';

// Serve config.js with env fallback if SUPABASE_URL and SUPABASE_ANON_KEY are provided
app.get('/config.js', (req, res) => {
  const url = process.env.SUPABASE_URL || '';
  const anonKey = process.env.SUPABASE_ANON_KEY || '';
  if (url && anonKey) {
    res.type('application/javascript');
    return res.send(`window.MGHRM_CONFIG = {\n  url: ${JSON.stringify(url)},\n  anonKey: ${JSON.stringify(anonKey)}\n};\n`);
  }
  res.sendFile(path.join(__dirname, 'config.js'));
});

// Serve static assets from root directory
app.use(express.static(path.join(__dirname)));

// SPA fallback to index.html
app.get('*', (req, res) => {
  res.sendFile(path.join(__dirname, 'index.html'));
});

app.listen(PORT, HOST, () => {
  console.log(`MG Security HRM Suite running at http://${HOST}:${PORT}`);
});

