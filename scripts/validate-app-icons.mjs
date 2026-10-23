// Installable icons are generated once from the approved source and versioned.
// Publishing validates the exact assets without an apt/network dependency.
import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import {fileURLToPath} from 'node:url';
const approved=JSON.parse(fs.readFileSync(new URL('./approved-app-icons.json',import.meta.url),'utf8'));
export function validateAppIcons(directory){
 for(const [name,expected] of Object.entries(approved)){
  const bytes=fs.readFileSync(path.join(directory,name));
  if(crypto.createHash('sha256').update(bytes).digest('hex')!==expected)throw Error('Approved icon content mismatch: '+name);
 }
 for(const [name,size] of [['icon-192.png',192],['icon-512.png',512],['notification-small-m-96.png',96]]){
  const bytes=fs.readFileSync(path.join(directory,name));
  if(bytes.length<24||bytes.subarray(0,8).toString('hex')!=='89504e470d0a1a0a'||bytes.toString('ascii',12,16)!=='IHDR'||bytes.readUInt32BE(16)!==size||bytes.readUInt32BE(20)!==size)throw Error('Invalid installable icon dimensions: '+name);
 }
}
if(process.argv[1]&&path.resolve(process.argv[1])===fileURLToPath(import.meta.url)){
 if(process.argv.length!==3)throw Error('Usage: node scripts/validate-app-icons.mjs <public-directory>');
 validateAppIcons(process.argv[2]);console.log('Approved icon hashes and installable dimensions verified.');
}
