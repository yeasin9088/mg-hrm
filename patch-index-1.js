const fs = require('fs');
let html = fs.readFileSync('index.html', 'utf8');

// The inline MGHRM definition
const startStr = "/* =====================================================================\n   MG SECURITY HRM — Supabase Data Layer  (v1.0)";
const endStr = "global.MGHRM = {\n    connect: connect, isReady: isReady,\n    signIn: signIn, signUp: signUp, signOut: signOut,\n    getSession: getSession, onChange: onChange, currentUser: currentUser, myProfile: myProfile,\n    loadAll: loadAll, upsert: upsert, remove: remove,\n    pushAll: pushAll, doPush: doPush,\n    bulkUpload: bulkUpload, seedReferenceTables: seedReferenceTables,\n    TABLE_MAP: TABLE_MAP, toDb: toDb, fromDb: fromDb,\n    _client: raw, _view: sqlView,\n    version: '1.0.0'\n  };\n})(window);";

const startIndex = html.indexOf(startStr);
const endIndex = html.indexOf(endStr);

if (startIndex > -1 && endIndex > -1) {
    const sectionToRemove = html.substring(startIndex, endIndex + endStr.length);
    html = html.replace(sectionToRemove, "/* MGHRM Data Layer now loaded from app-core.js */");
    
    // Add the script tag if not exists
    if (!html.includes('<script src="./app-core.js"></script>')) {
        html = html.replace('<script src="./config.js"></script>', '<script src="./config.js"></script>\n<script src="./app-core.js"></script>');
    }
    fs.writeFileSync('index.html', html);
    console.log('Inline Data Layer removed, app-core.js linked.');
} else {
    console.log('Could not find the exact inline data layer signature.');
}
