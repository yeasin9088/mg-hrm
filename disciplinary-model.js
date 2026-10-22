(function (root, factory) {
  const model = factory();
  if (typeof module === 'object' && module.exports) module.exports = model;
  if (root) root.MGDisciplinary = model;
})(typeof window !== 'undefined' ? window : globalThis, function () {
  'use strict';
  const types = Object.freeze([
    Object.freeze({en:'Show Cause Notice', bn:'কারণ দর্শানোর নোটিশ'}),
    Object.freeze({en:'Warning Letter', bn:'সতর্কীকরণ পত্র'}),
    Object.freeze({en:'Final Warning Letter', bn:'চূড়ান্ত সতর্কীকরণ পত্র'}),
    Object.freeze({en:'Final Show Cause Notice', bn:'চূড়ান্ত কারণ দর্শানোর নোটিশ'}),
    Object.freeze({en:'Suspension Order', bn:'সাময়িক বরখাস্তের আদেশ'}),
    Object.freeze({en:'Suspension Revocation Order', bn:'সাময়িক বরখাস্ত প্রত্যাহারের আদেশ'}),
    Object.freeze({en:'Dismissal Order', bn:'চাকরি হতে বরখাস্তের আদেশ'})
  ]);
  const legacy = Object.freeze({
    'Show-Cause Notice':'শোকজ নোটিশ',
    'কারণ-দর্শানো নোটিশ':'কারণ-দর্শানো নোটিশ',
    'বরখাস্তের আদেশ':'বরখাস্তের আদেশ',
    'Termination Order':'চাকরিচ্যুতির আদেশ',
    'Suspension':'সাময়িক বরখাস্ত আদেশ'
  });
  const datePattern = /^\d{4}-(0[1-9]|1[0-2])-([0-2]\d|3[01])$/;
  function validDate(value) {
    if (!datePattern.test(value || '')) return false;
    const d = new Date(value + 'T00:00:00Z');
    return Number.isFinite(d.getTime()) && d.toISOString().slice(0,10) === value;
  }
  function validate(fields) {
    if (!validDate(fields.incident_date)) return 'Enter a valid Incident Date.';
    if (!validDate(fields.issue_date)) return 'Enter a valid Issue Date.';
    if (!String(fields.description || '').trim()) return 'Enter a Letter Body.';
    return '';
  }
  function title(value) {
    const known = types.find(t => t.en === value || t.bn === value);
    return known ? known.bn : (legacy[value] || value || '');
  }
  function escape(value) {
    return String(value).replace(/[&<>"']/g, c => ({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
  }
  function plainParagraphs(value) {
    const s = String(value || '').replace(/\r\n?/g, '\n');
    return s.split(/\n+/).filter(line => line.trim()).map(line => '<p class="dc-paragraph">' + escape(line) + '</p>').join('');
  }
  return Object.freeze({types, title, validate, validDate, plainParagraphs});
});
