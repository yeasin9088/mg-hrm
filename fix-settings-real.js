const fs = require('fs');
let html = fs.readFileSync('index.html', 'utf8');

const replacement = `/*" onchange="handleLogoUpload(event)">
            </div>
          </div>
          <div class="form-grid">
            <div class="field"><label>Company Name</label><input type="text" id="setCompanyName" value="\${COMPANY.name||''}"></div>
            <div class="field"><label>Company Name (Bengali)</label><input type="text" id="setCompanyNameBn" value="\${COMPANY.nameBn||''}"></div>
            <div class="field wide"><label>Address</label><input type="text" id="setCompanyAddress" value="\${COMPANY.address||''}"></div>
            <div class="field wide"><label>Address (Bengali)</label><input type="text" id="setCompanyAddressBn" value="\${COMPANY.addressBn||''}"></div>
            <div class="field"><label>Phone</label><input type="text" id="setCompanyPhone" value="\${COMPANY.phone||''}"></div>
            <div class="field"><label>Phone (English)</label><input type="text" id="setCompanyPhoneEn" value="\${COMPANY.phoneEn||''}"></div>
            <div class="field"><label>Email</label><input type="text" id="setCompanyEmail" value="\${COMPANY.email||''}"></div>
          </div>
          <button class="btn primary" style="margin-top:16px" onclick="saveCompanyProfile()">Save Profile</button>
        </div>
      </div>
    </div>\`;
}
function handleLogoUpload(e) {
  const file = e.target.files[0];
  if (!file) return;
  const reader = new FileReader();
  reader.onload = function(evt) {
    COMPANY.logoDataUrl = evt.target.result;
    document.getElementById('logoPreview').innerHTML = \`<img src="\${COMPANY.logoDataUrl}" style="max-width:100%;max-height:100%;object-fit:contain">\`;
    persist();
  };
  reader.readAsDataURL(file);
}
function saveCompanyProfile() {
  COMPANY.name = document.getElementById('setCompanyName').value;
  COMPANY.nameBn = document.getElementById('setCompanyNameBn').value;
  COMPANY.address = document.getElementById('setCompanyAddress').value;
  COMPANY.addressBn = document.getElementById('setCompanyAddressBn').value;
  COMPANY.phone = document.getElementById('setCompanyPhone').value;
  COMPANY.phoneEn = document.getElementById('setCompanyPhoneEn').value;
  COMPANY.email = document.getElementById('setCompanyEmail').value;
  persist();
  toast('Company profile saved', 'success');
}
function importHint(){`;

let idx = html.indexOf('accept="imagefunction importHint(){');
if (idx !== -1) {
    html = html.substring(0, idx) + 'accept="image' + replacement + html.substring(idx + 35);
    fs.writeFileSync('index.html', html);
    console.log("Fixed manually via indexOf!");
} else {
    // maybe there are spaces
    let match = html.match(/accept="image[\s\S]{0,10}function importHint\(\)\{/);
    if (match) {
        html = html.substring(0, match.index) + 'accept="image' + replacement + html.substring(match.index + match[0].length - 21 /* length of function importHint(){ */);
        fs.writeFileSync('index.html', html);
        console.log("Fixed via match!");
    } else {
        console.log("Still not found...");
    }
}
